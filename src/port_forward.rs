use std::sync::{Arc, RwLock};

use crate::client::*;
use hbb_common::{
    allow_err, bail,
    config::READ_TIMEOUT,
    futures::{SinkExt, StreamExt},
    log,
    message_proto::*,
    protobuf::Message as _,
    rendezvous_proto::ConnType,
    tcp, timeout,
    tokio::{self, net::TcpStream, sync::mpsc},
    tokio_util::codec::{BytesCodec, Framed},
    ResultType, Stream,
};

fn run_rdp(port: u16) {
    std::process::Command::new("cmdkey")
        .arg("/delete:localhost")
        .output()
        .ok();
    let username = std::env::var("rdp_username").unwrap_or_default();
    let password = std::env::var("rdp_password").unwrap_or_default();
    if !username.is_empty() || !password.is_empty() {
        let mut args = vec!["/generic:localhost".to_owned()];
        if !username.is_empty() {
            args.push(format!("/user:{}", username));
        }
        if !password.is_empty() {
            args.push(format!("/pass:{}", password));
        }
        std::process::Command::new("cmdkey")
            .args(&args)
            .output()
            .ok();
    }
    std::process::Command::new("mstsc")
        .arg(format!("/v:localhost:{}", port))
        .spawn()
        .ok();
}

pub async fn listen(
    id: String,
    password: String,
    port: i32,
    interface: impl Interface,
    ui_receiver: mpsc::UnboundedReceiver<Data>,
    key: &str,
    token: &str,
    lc: Arc<RwLock<LoginConfigHandler>>,
    remote_host: String,
    remote_port: i32,
) -> ResultType<()> {
    let listener = tcp::new_listener(format!("127.0.0.1:{}", port), true).await?;
    let addr = listener.local_addr()?;
    log::info!("listening on port {:?}", addr);
    let is_rdp = port == 0;
    if is_rdp {
        run_rdp(addr.port());
    }
    let mut ui_receiver = ui_receiver;
    let mut forward_tasks: Vec<tokio::task::JoinHandle<()>> = Vec::new();
    loop {
        tokio::select! {
            Ok((forward, addr)) = listener.accept() => {
                log::info!("new connection from {:?}", addr);
                lc.write().unwrap().port_forward = (remote_host.clone(), remote_port);
                let id = id.clone();
                let password = password.clone();
                let mut forward = Framed::new(forward, BytesCodec::new());
                let mut close_port_forward = false;
                let park_id = crate::raatik::new_forward_park_id();
                match connect_and_login(&id, &password, &mut ui_receiver, interface.clone(), &mut forward, key, token, is_rdp, &park_id, &mut close_port_forward).await {
                    Ok(Some(authenticated)) => {
                        let interface = interface.clone();
                        let parked = crate::raatik::ParkedForwardGuard::new(
                            authenticated.park_id.clone(),
                        );
                        forward_tasks.push(tokio::spawn(async move {
                            // On drop, finishes this connection's parked interval if adopt did not take it.
                            let _parked = parked;
                            if let Err(err) = run_forward(forward, authenticated).await {
                                interface.msgbox("error", "Error", &err.to_string(), "");
                            }
                            log::info!("connection from {:?} closed", addr);
                       }));
                    }
                    _ if close_port_forward => {
                        break;
                    }
                    Err(err) => {
                        interface.on_establish_connection_error(err.to_string());
                    }
                    _ => {}
                }
            }
            d = ui_receiver.recv() => {
                match d {
                    Some(Data::Close) => {
                        break;
                    }
                    Some(Data::NewRDP) => {
                        println!("receive run_rdp from ui_receiver");
                        run_rdp(addr.port());
                    }
                    _ => {}
                }
            }
        }
    }
    // Close and listener exit must finish parked intervals without another forward poll.
    for task in &forward_tasks {
        task.abort();
    }
    for task in forward_tasks {
        let _ = task.await;
    }
    Ok(())
}

async fn connect_and_login(
    id: &str,
    password: &str,
    ui_receiver: &mut mpsc::UnboundedReceiver<Data>,
    interface: impl Interface,
    forward: &mut Framed<TcpStream, BytesCodec>,
    key: &str,
    token: &str,
    is_rdp: bool,
    park_id: &str,
    close_port_forward: &mut bool,
) -> ResultType<Option<AuthenticatedForward>> {
    let conn_type = if is_rdp {
        ConnType::RDP
    } else {
        ConnType::PORT_FORWARD
    };
    let ((mut stream, direct, _pk, _kcp, _stream_type), (feedback, rendezvous_server)) =
        Client::start(id, key, token, conn_type, interface.clone()).await?;
    interface.update_direct(Some(direct));
    if !stream.is_secured() && !crate::common::is_direct_ip_access(id) {
        if !confirm_insecure_connection(&interface, ui_receiver).await {
            *close_port_forward = true;
            return Ok(None);
        }
    }
    let mut buffer = Vec::new();
    let mut received = false;
    let mut history = None;

    let _keep_it = hc_connection(feedback, rendezvous_server, token).await;

    loop {
        tokio::select! {
            res = timeout(READ_TIMEOUT, stream.next()) => match res {
                Err(_) => {
                    bail!("Timeout");
                }
                Ok(Some(Ok(bytes))) => {
                    if !received {
                        received = true;
                        interface.update_received(true);
                    }
                    let msg_in = Message::parse_from_bytes(&bytes)?;
                    match msg_in.union {
                        Some(message::Union::Hash(hash)) => {
                            interface.handle_hash(password, hash, &mut stream).await;
                        }
                        Some(message::Union::LoginResponse(lr)) => match lr.union {
                            Some(login_response::Union::Error(err)) => {
                                if !interface.handle_login_error(&err) {
                                    return Ok(None);
                                }
                            }
                            Some(login_response::Union::PeerInfo(pi)) => {
                                let hostname = pi.hostname.clone();
                                history = start_forward_history(id, &hostname, is_rdp, &interface, park_id).await;
                                interface.handle_peer_info(pi);
                                break;
                            }
                            _ => {}
                        }
                        Some(message::Union::TestDelay(t)) => {
                            interface.handle_test_delay(t, &mut stream).await;
                        }
                        _ => {}
                    }
                }
                Ok(Some(Err(err))) => {
                    bail!("Connection closed: {}", err);
                }
                _ => {
                    bail!("Reset by the peer");
                }
            },
            d = ui_receiver.recv() => {
                match d {
                    Some(Data::Login((os_username, os_password, password, remember))) => {
                        interface.handle_login_from_ui(os_username, os_password, password, remember, &mut stream).await;
                    }
                    Some(Data::Message(msg)) => {
                        allow_err!(stream.send(&msg).await);
                    }
                    _ => {}
                }
            },
            res = forward.next() => {
                if let Some(Ok(bytes)) = res {
                    buffer.extend(bytes);
                } else {
                    return Ok(None);
                }
            },
        }
    }
    stream.set_raw();
    if !buffer.is_empty() {
        allow_err!(stream.send_bytes(buffer.into()).await);
    }
    Ok(Some(AuthenticatedForward {
        stream,
        history,
        park_id: park_id.to_owned(),
    }))
}

struct AuthenticatedForward {
    stream: Stream,
    history: Option<crate::raatik::HistoryInterval>,
    park_id: String,
}

async fn start_forward_history(
    id: &str,
    hostname: &str,
    is_rdp: bool,
    interface: &impl Interface,
    park_id: &str,
) -> Option<crate::raatik::HistoryInterval> {
    #[cfg(not(windows))]
    {
        let _ = (id, hostname, is_rdp, interface, park_id);
        None
    }
    #[cfg(windows)]
    {
        let alias = interface.get_lch().read().unwrap().get_option("alias");
        let peer_id = id.to_owned();
        let peer_name = crate::raatik::snapshot_peer_name(&alias, hostname, &peer_id);
        let kind = if is_rdp { "rdp" } else { "port_forward" }.to_owned();
        let session_key = interface.history_session_key();
        let park_id = park_id.to_owned();
        match tokio::task::spawn_blocking(move || {
            crate::raatik::begin_forward_interval(session_key, park_id, peer_id, peer_name, kind)
        })
        .await
        {
            Ok(Ok(interval)) => interval,
            Ok(Err(err)) => {
                log::warn!("history start failed: {err}");
                None
            }
            Err(err) => {
                log::warn!("history start task failed: {err}");
                None
            }
        }
    }
}

async fn run_forward(
    forward: Framed<TcpStream, BytesCodec>,
    authenticated: AuthenticatedForward,
) -> ResultType<()> {
    log::info!("new port forwarding connection started");
    let mut forward = forward;
    let AuthenticatedForward {
        mut stream,
        mut history,
        park_id,
    } = authenticated;
    let mut checkpoint_job: Option<tokio::task::JoinHandle<()>> = None;
    let mut checkpoint_timer = tokio::time::interval_at(
        tokio::time::Instant::now() + std::time::Duration::from_secs(30),
        std::time::Duration::from_secs(30),
    );
    loop {
        tokio::select! {
            res = forward.next() => {
                if let Some(Ok(bytes)) = res {
                    allow_err!(stream.send_bytes(bytes.into()).await);
                } else {
                    break;
                }
            },
            res = stream.next() => {
                if let Some(Ok(bytes)) = res {
                    allow_err!(forward.send(bytes).await);
                } else {
                    break;
                }
            },
            _ = checkpoint_timer.tick(), if cfg!(windows) => {
                if history.is_none() {
                    crate::raatik::adopt_retried_forward(&mut history, &park_id);
                }
                if checkpoint_job.as_ref().is_some_and(|job| !job.is_finished()) {
                    continue;
                }
                checkpoint_job = None;
                if let Some(interval) = history.clone() {
                    checkpoint_job = Some(tokio::task::spawn_blocking(move || {
                        if let Err(err) = interval.checkpoint() {
                            log::warn!("history checkpoint failed: {err}");
                        }
                    }));
                }
            }
        }
    }
    if let Some(job) = checkpoint_job {
        let _ = job.await;
    }
    if history.is_none() {
        crate::raatik::adopt_retried_forward(&mut history, &park_id);
    }
    if let Some(interval) = history {
        let _ = tokio::task::spawn_blocking(move || {
            if let Err(err) = interval.finish() {
                log::warn!("history finish failed: {err}");
            }
        })
        .await;
    }
    Ok(())
}
