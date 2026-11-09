import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/raatik/dialogs/dialog_style.dart';
import 'package:flutter_hbb/raatik/files/transfer_surface.dart';
import 'package:flutter_hbb/raatik/text/identifier_widgets.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

/// Which dialog the key policy applies to.
enum RaatikModalRole { approval, credential, cancellable }

/// The action that currently owns focus inside a modal.
enum RaatikModalFocus { accept, reject, cancel, submit, other }

/// What a key should do. [none] must not accept, reject, or connect.
enum RaatikModalEffect { accept, reject, cancel, none }

bool _isEnter(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;

bool _isEscape(LogicalKeyboardKey key) => key == LogicalKeyboardKey.escape;

/// Enter activates only the focused action. Escape rejects an approval and
/// cancels every other dialog. A credential dialog never accepts on Escape,
/// and Enter in a text field does not connect.
RaatikModalEffect raatikModalEffect({
  required RaatikModalRole role,
  required LogicalKeyboardKey key,
  required RaatikModalFocus focus,
  bool composing = false,
}) {
  if (_isEscape(key)) {
    switch (role) {
      case RaatikModalRole.approval:
        return RaatikModalEffect.reject;
      case RaatikModalRole.credential:
      case RaatikModalRole.cancellable:
        return RaatikModalEffect.cancel;
    }
  }
  if (!_isEnter(key) || composing) return RaatikModalEffect.none;
  switch (role) {
    case RaatikModalRole.approval:
      if (focus == RaatikModalFocus.accept) return RaatikModalEffect.accept;
      if (focus == RaatikModalFocus.reject) return RaatikModalEffect.reject;
      return RaatikModalEffect.none;
    case RaatikModalRole.credential:
      if (focus == RaatikModalFocus.submit || focus == RaatikModalFocus.accept) {
        return RaatikModalEffect.accept;
      }
      if (focus == RaatikModalFocus.cancel || focus == RaatikModalFocus.reject) {
        return RaatikModalEffect.cancel;
      }
      return RaatikModalEffect.none;
    case RaatikModalRole.cancellable:
      if (focus == RaatikModalFocus.accept || focus == RaatikModalFocus.submit) {
        return RaatikModalEffect.accept;
      }
      if (focus == RaatikModalFocus.cancel || focus == RaatikModalFocus.reject) {
        return RaatikModalEffect.cancel;
      }
      return RaatikModalEffect.none;
  }
}

/// Removes [secret] from a message before it is shown. Empty secrets are ignored.
String raatikRedactSecret(String message, String secret) {
  if (secret.isEmpty) return message;
  return message.replaceAll(secret, '');
}

/// Tags the focused control so Enter can tell accept from cancel.
class RaatikDialogAction extends InheritedWidget {
  const RaatikDialogAction({
    super.key,
    required this.focus,
    required super.child,
  });

  final RaatikModalFocus focus;

  static RaatikModalFocus read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<RaatikDialogAction>();
    final tagged = element?.widget;
    if (tagged is RaatikDialogAction) return tagged.focus;
    return RaatikModalFocus.other;
  }

  @override
  bool updateShouldNotify(RaatikDialogAction oldWidget) =>
      focus != oldWidget.focus;
}

/// Moves focus among [scope]'s descendants and does not leave the scope.
void raatikCycleFocus(FocusNode scope, bool forward) {
  final nodes = scope.descendants
      .where((node) => node.canRequestFocus && !node.skipTraversal)
      .toList();
  if (nodes.isEmpty) return;
  final current = FocusManager.instance.primaryFocus;
  var index = current == null ? -1 : nodes.indexOf(current);
  if (index < 0) {
    (forward ? nodes.first : nodes.last).requestFocus();
    return;
  }
  final next = forward
      ? (index + 1) % nodes.length
      : (index - 1 + nodes.length) % nodes.length;
  nodes[next].requestFocus();
}

/// Key handler for [CustomAlertDialog] when a [RaatikModalRole] is set.
KeyEventResult raatikCustomDialogKey({
  required RaatikModalRole role,
  required RawKeyEvent key,
  required FocusNode scope,
  required VoidCallback? onAccept,
  required VoidCallback? onCancel,
  required BuildContext? focusContext,
}) {
  final logical = key.logicalKey;
  final enter = _isEnter(logical);
  final escape = _isEscape(logical);
  if (logical == LogicalKeyboardKey.tab) {
    if (key is RawKeyDownEvent && !key.repeat) {
      raatikCycleFocus(scope, !key.isShiftPressed);
    }
    return KeyEventResult.handled;
  }
  if (!enter && !escape) return KeyEventResult.ignored;
  if (key is! RawKeyDownEvent || key.repeat) return KeyEventResult.handled;
  final focus = focusContext == null
      ? RaatikModalFocus.other
      : RaatikDialogAction.read(focusContext);
  final effect = raatikModalEffect(
    role: role,
    key: logical,
    focus: focus,
  );
  switch (effect) {
    case RaatikModalEffect.accept:
      onAccept?.call();
      break;
    case RaatikModalEffect.reject:
    case RaatikModalEffect.cancel:
      onCancel?.call();
      break;
    case RaatikModalEffect.none:
      break;
  }
  return KeyEventResult.handled;
}

/// Focusable action inside [RaatikModalScope]. Descendants are not a second stop.
class RaatikModalAction extends StatelessWidget {
  const RaatikModalAction({
    super.key,
    required this.focus,
    required this.child,
    this.autofocus = false,
    this.focusNode,
  });

  final RaatikModalFocus focus;
  final Widget child;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return RaatikDialogAction(
      focus: focus,
      child: Focus(
        focusNode: focusNode,
        autofocus: autofocus,
        descendantsAreFocusable: false,
        child: child,
      ),
    );
  }
}

/// Keeps Tab inside the dialog and dispatches Enter/Escape through [raatikModalEffect].
class RaatikModalScope extends StatelessWidget {
  const RaatikModalScope({
    super.key,
    required this.role,
    required this.child,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  final RaatikModalRole role;
  final Widget child;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final logical = event.logicalKey;
    final enter = _isEnter(logical);
    final escape = _isEscape(logical);
    if (event is! KeyDownEvent) {
      if (enter || escape || logical == LogicalKeyboardKey.tab) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (logical == LogicalKeyboardKey.tab) {
      raatikCycleFocus(node, !HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (!enter && !escape) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus?.context;
    final focus =
        primary == null ? RaatikModalFocus.other : RaatikDialogAction.read(primary);
    final effect = raatikModalEffect(
      role: role,
      key: logical,
      focus: focus,
    );
    switch (effect) {
      case RaatikModalEffect.accept:
        onAccept?.call();
        break;
      case RaatikModalEffect.reject:
        onReject?.call();
        break;
      case RaatikModalEffect.cancel:
        onCancel?.call();
        break;
      case RaatikModalEffect.none:
        break;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      onKeyEvent: _onKey,
      child: child,
    );
  }
}

class RaatikPermissionChoice {
  const RaatikPermissionChoice({
    required this.id,
    required this.label,
    required this.enabled,
  });

  final String id;
  final String label;
  final bool enabled;

  RaatikPermissionChoice copyWith({bool? enabled}) => RaatikPermissionChoice(
        id: id,
        label: label,
        enabled: enabled ?? this.enabled,
      );
}

Future<void> showRaatikApprovalDialog({
  required BuildContext context,
  required String requesterName,
  required String requesterId,
  required List<RaatikPermissionChoice> permissions,
  required ValueChanged<RaatikPermissionChoice> onPermission,
  required VoidCallback onAccept,
  required VoidCallback onReject,
  String? error,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _RaatikApprovalDialog(
        requesterName: requesterName,
        requesterId: requesterId,
        permissions: permissions,
        onPermission: onPermission,
        onAccept: () {
          onAccept();
          Navigator.of(dialogContext).pop();
        },
        onReject: () {
          onReject();
          Navigator.of(dialogContext).pop();
        },
        error: error,
      );
    },
  );
}

class _RaatikApprovalDialog extends StatefulWidget {
  const _RaatikApprovalDialog({
    required this.requesterName,
    required this.requesterId,
    required this.permissions,
    required this.onPermission,
    required this.onAccept,
    required this.onReject,
    this.error,
  });

  final String requesterName;
  final String requesterId;
  final List<RaatikPermissionChoice> permissions;
  final ValueChanged<RaatikPermissionChoice> onPermission;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String? error;

  @override
  State<_RaatikApprovalDialog> createState() => _RaatikApprovalDialogState();
}

class _RaatikApprovalDialogState extends State<_RaatikApprovalDialog> {
  final _rejectNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rejectNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rejectNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return RaatikModalScope(
      role: RaatikModalRole.approval,
      onAccept: widget.onAccept,
      onReject: widget.onReject,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaatikTokens.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width < RaatikDialogStyle.maxWidth
                ? width - 32
                : RaatikDialogStyle.maxWidth,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: RaatikDialogStyle.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.requesterName),
                  const SizedBox(height: 8),
                  RaatikIdentifierText(widget.requesterId),
                  for (final permission in widget.permissions)
                    Focus(
                      child: Builder(
                        builder: (focusContext) => SwitchListTile(
                          key: Key('approval-perm-${permission.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(permission.label),
                          value: permission.enabled,
                          onChanged: (enabled) {
                            Focus.of(focusContext).requestFocus();
                            widget.onPermission(
                              permission.copyWith(enabled: enabled),
                            );
                          },
                        ),
                      ),
                    ),
                  if (widget.error != null)
                    RaatikWrappingError(message: widget.error!),
                  const SizedBox(height: 8),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: [
                      RaatikModalAction(
                        focus: RaatikModalFocus.reject,
                        focusNode: _rejectNode,
                        autofocus: true,
                        child: OutlinedButton(
                          key: const Key('approval-reject'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: raatikDialogButtonMinSize,
                          ),
                          onPressed: widget.onReject,
                          child: const Text('Reject'),
                        ),
                      ),
                      RaatikModalAction(
                        focus: RaatikModalFocus.accept,
                        child: ElevatedButton(
                          key: const Key('approval-accept'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            minimumSize: raatikDialogButtonMinSize,
                          ),
                          onPressed: widget.onAccept,
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showRaatikCredentialDialog({
  required BuildContext context,
  required TextEditingController password,
  required String error,
  required VoidCallback onSubmit,
  required VoidCallback onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _RaatikCredentialDialog(
        password: password,
        error: error,
        onSubmit: () {
          onSubmit();
          Navigator.of(dialogContext).pop();
        },
        onCancel: () {
          onCancel();
          Navigator.of(dialogContext).pop();
        },
      );
    },
  );
}

class _RaatikCredentialDialog extends StatelessWidget {
  const _RaatikCredentialDialog({
    required this.password,
    required this.error,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController password;
  final String error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width < RaatikTokens.confirmDialogMax
        ? width - 32
        : RaatikTokens.confirmDialogMax;
    final shown = raatikRedactSecret(error, password.text);
    return RaatikModalScope(
      role: RaatikModalRole.credential,
      onAccept: onSubmit,
      onCancel: onCancel,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaatikTokens.radiusXl),
        ),
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Padding(
              padding: RaatikDialogStyle.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('credential-password'),
                    controller: password,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  RaatikWrappingError(
                    textKey: const Key('raatik-wrapping-error'),
                    message: shown,
                  ),
                  const SizedBox(height: 12),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      RaatikModalAction(
                        focus: RaatikModalFocus.cancel,
                        child: OutlinedButton(
                          key: const Key('credential-cancel'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: raatikDialogButtonMinSize,
                          ),
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      RaatikModalAction(
                        focus: RaatikModalFocus.submit,
                        child: ElevatedButton(
                          key: const Key('credential-submit'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            minimumSize: raatikDialogButtonMinSize,
                          ),
                          onPressed: onSubmit,
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
