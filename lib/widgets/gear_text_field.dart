// The wrapper intentionally mirrors TextFormField's constructor while adding
// a small shared field contract.
// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared text input used throughout GearTracker.
///
/// It intentionally extends Flutter's [TextFormField], so existing callers
/// and widget tests retain the same field identity while decoration and the
/// supported input contract stay centralized here.
class GearTextField extends TextFormField {
  GearTextField({
    super.key,
    TextEditingController? controller,
    String? initialValue,
    ValueChanged<String>? onChanged,
    GestureTapCallback? onTap,
    ValueChanged<String>? onFieldSubmitted,
    VoidCallback? onEditingComplete,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    bool? enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    FocusNode? focusNode,
    TextStyle? style,
    TextAlign textAlign = TextAlign.start,
    AutovalidateMode? autovalidateMode,
    InputDecoration? decoration,
  }) : inputDecoration = decoration ?? const InputDecoration(),
       assert(
         controller == null || initialValue == null,
         'Use controller or initialValue, not both.',
       ),
       super(
         controller: controller,
         initialValue: initialValue,
         onChanged: onChanged,
         onTap: onTap,
         onFieldSubmitted: onFieldSubmitted,
         onEditingComplete: onEditingComplete,
         validator: validator,
         keyboardType: keyboardType,
         inputFormatters: inputFormatters,
         textCapitalization: textCapitalization,
         textInputAction: textInputAction,
         autofocus: autofocus,
         readOnly: readOnly,
         showCursor: showCursor,
         enabled: enabled,
         obscureText: obscureText,
         maxLines: maxLines,
         minLines: minLines,
         focusNode: focusNode,
         style: style,
         textAlign: textAlign,
         autovalidateMode: autovalidateMode,
          decoration: decoration ?? const InputDecoration(),
       );

  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool readOnly;
  final bool? showCursor;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final InputDecoration inputDecoration;
}
