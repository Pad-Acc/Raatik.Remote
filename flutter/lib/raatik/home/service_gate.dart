import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/svc_status.dart';
import 'package:flutter_hbb/raatik/theme/tokens.dart';

enum RaatikServicePhase { stopped, starting, connecting, ready, failed }

RaatikServicePhase deriveRaatikServicePhase({
  required bool stopped,
  required SvcStatus status,
  required bool startPending,
  required String? error,
}) {
  if (stopped) return RaatikServicePhase.stopped;
  if (error != null && error.isNotEmpty) return RaatikServicePhase.failed;
  if (startPending) {
    return status == SvcStatus.connecting
        ? RaatikServicePhase.connecting
        : RaatikServicePhase.starting;
  }
  switch (status) {
    case SvcStatus.connecting:
      return RaatikServicePhase.connecting;
    case SvcStatus.ready:
      return RaatikServicePhase.ready;
    case SvcStatus.notReady:
      return RaatikServicePhase.connecting;
  }
}

class RaatikServiceGateCopy {
  const RaatikServiceGateCopy({
    required this.stoppedTitle,
    required this.startLabel,
    required this.startingLabel,
    required this.readyLabel,
    required this.stoppedBody,
    required this.failedTitle,
    required this.retryBody,
  });

  final String stoppedTitle;
  final String startLabel;
  final String startingLabel;
  final String readyLabel;
  final String stoppedBody;
  final String failedTitle;
  final String retryBody;
}

class RaatikServiceGate extends StatelessWidget {
  const RaatikServiceGate({
    super.key,
    required this.phase,
    required this.copy,
    this.onStart,
  });

  final RaatikServicePhase phase;
  final RaatikServiceGateCopy copy;
  final VoidCallback? onStart;

  bool get _isCritical =>
      phase == RaatikServicePhase.stopped || phase == RaatikServicePhase.failed;

  bool get _isBusy =>
      phase == RaatikServicePhase.starting ||
      phase == RaatikServicePhase.connecting;

  String get _title {
    switch (phase) {
      case RaatikServicePhase.failed:
        return copy.failedTitle;
      case RaatikServicePhase.starting:
      case RaatikServicePhase.connecting:
        return copy.startingLabel;
      case RaatikServicePhase.stopped:
        return copy.stoppedTitle;
      case RaatikServicePhase.ready:
        return copy.readyLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (phase == RaatikServicePhase.ready) {
      return Semantics(
        liveRegion: true,
        container: true,
        child: _ReadyRow(label: copy.readyLabel),
      );
    }

    final dangerBg = isDark
        ? RaatikTokens.danger.withOpacity(0.14)
        : RaatikTokens.danger.withOpacity(0.08);
    final borderColor = RaatikTokens.danger.withOpacity(isDark ? 0.55 : 0.35);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isCritical ? dangerBg : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
          border: Border.all(
            color: _isCritical ? borderColor : theme.dividerColor,
            width: _isCritical ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _isCritical ? RaatikTokens.danger : null,
              ),
            ),
            if (phase == RaatikServicePhase.stopped) ...[
              const SizedBox(height: 8),
              Text(
                copy.stoppedBody,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: RaatikTokens.minTarget,
              child: ElevatedButton(
                onPressed: _isBusy ? null : onStart,
                child: _isBusy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(copy.startingLabel),
                        ],
                      )
                    : Text(
                        phase == RaatikServicePhase.failed
                            ? copy.retryBody
                            : copy.startLabel,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? RaatikTokens.success.withOpacity(0.14)
        : RaatikTokens.success.withOpacity(0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RaatikTokens.radiusSm),
        border: Border.all(color: RaatikTokens.success.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: RaatikTokens.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: RaatikTokens.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
