import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Standardized Form Input Field for text, numbers, and currency inputs.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final String? prefixText;
  final Widget? suffix;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefix,
    this.prefixText,
    this.suffix,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.textInputAction,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    Widget? effectiveSuffix = suffix;
    if (effectiveSuffix == null && suffixIcon != null) {
      effectiveSuffix = IconButton(
        icon: Icon(suffixIcon, size: 20, color: context.themeTextSecondary),
        onPressed: onSuffixTap,
      );
    }

    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: AppTypography.bodyLarge.copyWith(
        color: enabled ? context.themeTextPrimary : context.themeTextDisabled,
      ),
      cursorColor: AppColors.brandGreen,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: context.themeTextSecondary.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: context.themeTileBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: prefix,
        prefixText: prefixText,
        prefixStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.brandGreen,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: effectiveSuffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.destructiveRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.destructiveRed, width: 1.5),
        ),
      ),
    );

    if (label == null || label!.isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: AppTypography.caption.copyWith(
            color: context.themeTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
