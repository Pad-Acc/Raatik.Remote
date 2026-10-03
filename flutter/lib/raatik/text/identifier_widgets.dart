import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/raatik/bidi/ltr_isolate.dart';
import 'package:flutter_hbb/raatik/theme/text_styles.dart';

/// Re-applies the Latin-digit identifier face after merging the caller's
/// [style]. `TextStyle.merge` returns the caller's style wholesale when it
/// was built with `inherit: false` (e.g. `Theme.of(context).textTheme.*`),
/// which drops the Latin-digit family, fallback and tabular figures. Used by
/// both [RaatikIdentifierText] and [RaatikIdentifierField] so the identifier
/// face survives regardless of what style the caller passes.
TextStyle _identifierStyle(BuildContext context, TextStyle? style) {
  return RaatikTextStyles.identifier(context).merge(style).copyWith(
    fontFamily: kRaatikIdentifierFontFamily,
    fontFamilyFallback: kRaatikIdentifierFontFallback,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Read-only identifier (ID, password, version, IP) rendered as an LTR island
/// in the Latin-digit identifier style. [group] applies 3-3-3 grouping; pass
/// false for secrets, versions and addresses.
class RaatikIdentifierText extends StatelessWidget {
  const RaatikIdentifierText(
    this.value, {
    super.key,
    this.group = true,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String value;
  final bool group;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final shown = group ? formatID(value) : value;
    return Text(
      ltrIsolate(shown),
      style: _identifierStyle(context, style),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines ?? 1,
    );
  }
}

/// Editable or read-only identifier field: an LTR island whose hint keeps the
/// app's direction. Pair with [IDTextInputFormatter] for remote IDs or
/// [RaatikDigitsInputFormatter] for codes and ports.
class RaatikIdentifierField extends StatelessWidget {
  const RaatikIdentifierField({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.hintText,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.style,
    this.textAlign = TextAlign.center,
    this.decoration,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final GestureTapCallback? onTap;
  final TextStyle? style;
  final TextAlign textAlign;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    // Captured outside the LTR island so the Persian hint stays RTL.
    final hintDirection = Directionality.of(context);
    final base = decoration ?? const InputDecoration();
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textAlign: textAlign,
      maxLines: 1,
      style: _identifierStyle(context, style),
      inputFormatters: inputFormatters,
      decoration: base.copyWith(
        hintText: hintText ?? base.hintText,
        hintTextDirection: hintDirection,
        counterText: '',
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
    );
    // https://github.com/flutter/flutter/issues/153560 - Linux Mint semantics-bridge
    // freeze workaround for TextField/TextFormField, mirrored from
    // common.dart's WorkaroundFreezeLinuxMint extension (not imported here: it pulls
    // models/* into this widget).
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    return ltrTextDirection(
      child: isLinux ? ExcludeSemantics(child: field) : field,
    );
  }
}
