import 'package:flutter/material.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

/// Non-modal history-save warning for the connection that failed.
///
/// The action retries that session's save. It does not open a dialog and it
/// does not reconnect.
class HistorySaveStatus extends StatelessWidget {
  static const actionKey = Key('raatik-history-save-retry');

  const HistorySaveStatus({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onRetry,
    Key? actionKey,
  }) : retryKey = actionKey ?? HistorySaveStatus.actionKey;

  final String text;
  final String actionLabel;
  final VoidCallback onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: RaatikTokens.space4,
          vertical: RaatikTokens.space2,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: RaatikTokens.primary, size: 20),
            const SizedBox(width: RaatikTokens.space3),
            Expanded(
              child: Text(text, style: RaatikTextStyles.body(context)),
            ),
            const SizedBox(width: RaatikTokens.space3),
            TextButton(
              key: retryKey,
              style: TextButton.styleFrom(
                foregroundColor: RaatikTokens.primary,
                minimumSize: const Size(
                  RaatikTokens.minTarget,
                  RaatikTokens.minTarget,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRetry,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Places [HistorySaveStatus] over the current session window.
class HistorySaveStatusOverlay extends StatelessWidget {
  const HistorySaveStatusOverlay({
    super.key,
    required this.listenable,
    required this.text,
    required this.actionLabel,
    required this.onRetry,
    required this.child,
  });

  final Listenable listenable;
  final String? Function() text;
  final String? Function() actionLabel;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final message = text();
            final action = actionLabel();
            if (message == null ||
                message.isEmpty ||
                action == null ||
                action.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HistorySaveStatus(
                text: message,
                actionLabel: action,
                onRetry: onRetry,
              ),
            );
          },
        ),
      ],
    );
  }
}
