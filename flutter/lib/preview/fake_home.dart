import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/home/home_layout.dart';
import 'package:flutter_hbb/raatik/home/service_gate.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

/// Preview home using production [RaatikHomeLayout] and [RaatikServiceGate].
class FakeHomePage extends StatelessWidget {
  const FakeHomePage({
    super.key,
    required this.phase,
    required this.copy,
  });

  final RaatikServicePhase phase;
  final RaatikServiceGateCopy copy;

  bool get _blocked => phase != RaatikServicePhase.ready;

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return RaatikHomeLayout(
      serviceGate: RaatikServiceGate(
        phase: phase,
        copy: copy,
        onStart: () {},
      ),
      receivePanel: _FakeReceivePanel(isFa: isFa),
      connectPanel: _FakeConnectPanel(isFa: isFa),
      blocked: _blocked,
    );
  }
}

class _FakeReceivePanel extends StatelessWidget {
  const _FakeReceivePanel({required this.isFa});

  final bool isFa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Image.asset(
              'assets/logo.png',
              width: 64,
              height: 64,
              errorBuilder: (_, __, ___) => Icon(
                Icons.desktop_windows,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'RaatikDesk',
              style: theme.textTheme.titleMedium?.copyWith(
                color: RaatikTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFa
                      ? 'آماده برای پشتیبانی اتوفای'
                      : 'Ready for Autofai support',
                  textAlign: TextAlign.start,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isFa
                      ? 'شناسه این سیستم را برای پشتیبان بخوانید یا کپی کنید'
                      : 'Share this device ID with your support agent',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _CredentialRow(
            label: isFa ? 'شناسه من' : 'My ID',
            value: formatIDForDisplay('123456789'),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.copy, size: 20),
                tooltip: isFa ? 'کپی' : 'Copy',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CredentialRow(
            label: isFa ? 'رمز یک‌بارمصرف' : 'One-time password',
            value: ltrIsolate('842915'),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: isFa ? 'بروزرسانی' : 'Refresh',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.copy, size: 20),
                tooltip: isFa ? 'کپی' : 'Copy',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: RaatikTokens.minTarget,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(isFa ? 'کپی شناسه و رمز' : 'Copy ID and password'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeConnectPanel extends StatelessWidget {
  const _FakeConnectPanel({required this.isFa});

  final bool isFa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;

    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFa ? 'اتصال به سیستم دیگر' : 'Connect to another device',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  isFa ? 'برای تیم پشتیبانی' : 'For the support team',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isFa ? 'شناسه مقصد' : 'Remote ID',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {},
                  child: Text(isFa ? 'اتصال' : 'Connect'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Text(
              isFa ? 'اتصالات اخیر' : 'Recent connections',
              style: TextStyle(
                fontSize: 13,
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              children: [
                _PeerTile(
                  id: formatIDForDisplay('123456789'),
                  label: isFa ? 'دفتر مرکزی' : 'Head office',
                ),
                _PeerTile(
                  id: formatIDForDisplay('987654321'),
                  label: isFa ? 'لپ‌تاپ پشتیبانی' : 'Support laptop',
                ),
                _PeerTile(
                  id: formatIDForDisplay('551122334'),
                  label: isFa ? 'سیستم مشتری' : 'Customer PC',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.actions,
  });

  final String label;
  final String value;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(width: 2, height: 48, color: RaatikTokens.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: muted)),
                const SizedBox(height: 4),
                ltrTextDirection(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.id, required this.label});

  final String id;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.computer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(id, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
            size: 20,
          ),
        ],
      ),
    );
  }
}
