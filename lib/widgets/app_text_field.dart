import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Supported surface variants for [AppTextField].
enum AppTextFieldVariant {
  /// Standard dark surface (screens, cards, hubs).
  dark,

  /// Light / white background (e.g. homepage hero white section).
  light,

  /// Elevated modal dialogs and bottom drawers.
  modal,
}

/// Standardized Form Input Field for text, numbers, and search inputs.
///
/// Adheres strictly to:
/// - Zero borders / stroke lines (pure surface color contrast).
/// - Consistent heights (40px small, 48px standard, 54px large).
/// - Centralized surface variants (dark, light/onWhite, modal).
/// - Clean pill or rounded corners (`AppRadius.cardRadiusSm` / `100%`).
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool showClearButton;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final TextStyle? style;
  final AppTextFieldVariant variant;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? hintColor;
  final bool obscureText;
  final EdgeInsetsGeometry? contentPadding;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefix,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.suffixIcon,
    this.onSuffixTap,
    this.showClearButton = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.style,
    this.variant = AppTextFieldVariant.dark,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.hintColor,
    this.contentPadding,
  });

  /// Factory helper for light / onWhite background surfaces (e.g. homepage hero section).
  const AppTextField.onWhite({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefix,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.suffixIcon,
    this.onSuffixTap,
    this.showClearButton = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.style,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.hintColor,
    this.contentPadding,
  }) : variant = AppTextFieldVariant.light;

  /// Factory helper for modal dialogs and bottom drawers.
  const AppTextField.modal({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefix,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.suffixIcon,
    this.onSuffixTap,
    this.showClearButton = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.style,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.hintColor,
    this.contentPadding,
  }) : variant = AppTextFieldVariant.modal;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _effectiveController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
    _hasText = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      _effectiveController = widget.controller ?? TextEditingController(text: widget.initialValue);
      _effectiveController.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _effectiveController.dispose();
    } else {
      _effectiveController.removeListener(_handleTextChange);
    }
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve Colors based on variant
    Color defaultBg;
    Color defaultTextColor;
    Color defaultHintColor;
    Color defaultPrefixColor;

    switch (widget.variant) {
      case AppTextFieldVariant.light:
        defaultBg = Colors.black.withValues(alpha: 0.05);
        defaultTextColor = AppColors.buttonPrimaryText; // Dark Slate #0F172A
        defaultHintColor = const Color(0xFF64748B); // Slate Gray
        defaultPrefixColor = AppColors.buttonPrimaryText;
        break;
      case AppTextFieldVariant.modal:
        defaultBg = AppColors.drawerCard;
        defaultTextColor = Colors.white;
        defaultHintColor = Colors.white38;
        defaultPrefixColor = AppColors.positive;
        break;
      case AppTextFieldVariant.dark:
      default:
        defaultBg = AppColors.drawerCard;
        defaultTextColor = AppColors.textPrimary;
        defaultHintColor = AppColors.textSecondary.withValues(alpha: 0.55);
        defaultPrefixColor = AppColors.positive;
        break;
    }

    final effectiveBg = widget.backgroundColor ?? defaultBg;
    final effectiveTextColor = widget.textColor ?? defaultTextColor;
    final effectiveHintColor = widget.hintColor ?? defaultHintColor;

    final effectiveRadius = widget.borderRadius ??
        (widget.maxLines == 1
            ? BorderRadius.circular(16)
            : AppRadius.cardRadiusSm);

    // 2. Resolve Prefix
    Widget? effectivePrefix = widget.prefix;
    if (effectivePrefix == null && widget.prefixIcon != null) {
      effectivePrefix = Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(
          widget.prefixIcon,
          size: 20,
          color: defaultPrefixColor,
        ),
      );
    }

    // 3. Resolve Suffix
    Widget? effectiveSuffix = widget.suffix;
    if (effectiveSuffix == null && widget.showClearButton && _hasText && widget.enabled) {
      effectiveSuffix = IconButton(
        icon: Icon(
          Icons.cancel_rounded,
          size: 18,
          color: effectiveHintColor,
        ),
        splashRadius: 18,
        onPressed: () {
          _effectiveController.clear();
          widget.onChanged?.call('');
        },
      );
    } else if (effectiveSuffix == null && widget.suffixIcon != null) {
      effectiveSuffix = IconButton(
        icon: Icon(
          widget.suffixIcon,
          size: 20,
          color: effectiveHintColor,
        ),
        splashRadius: 18,
        onPressed: widget.onSuffixTap,
      );
    }

    // 4. Build Input Field
    final field = TextFormField(
      controller: _effectiveController,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      onTap: widget.onTap,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      textAlign: widget.textAlign,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      style: (widget.style ?? AppTypography.bodyMedium).copyWith(
        color: widget.enabled
            ? effectiveTextColor
            : effectiveTextColor.withValues(alpha: 0.4),
        fontWeight: FontWeight.w500,
      ),
      cursorColor: widget.variant == AppTextFieldVariant.light
          ? AppColors.buttonPrimaryText
          : AppColors.positive,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: effectiveHintColor,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: effectiveBg,
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        prefixIcon: effectivePrefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        prefixText: widget.prefixText,
        prefixStyle: AppTypography.bodyLarge.copyWith(
          color: defaultPrefixColor,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: effectiveSuffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        border: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide.none,
        ),
      ),
    );

    // 5. Wrap with Label if provided
    if (widget.label == null || widget.label!.isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style: AppTypography.caption.copyWith(
            color: widget.variant == AppTextFieldVariant.light
                ? AppColors.buttonPrimaryText.withValues(alpha: 0.8)
                : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
