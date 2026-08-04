import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/design_tokens.dart';

class ClayInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputType? textInputType;
  final AutovalidateMode autovalidateMode;

  const ClayInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.textInputType,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<ClayInput> createState() => _ClayInputState();
}

class _ClayInputState extends State<ClayInput> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null || _currentError != null;
    final effectiveError = widget.errorText ?? _currentError;

    Color borderColor;
    Color labelColor;

    if (hasError) {
      borderColor = ClayTokens.clayError;
      labelColor = ClayTokens.clayError;
    } else if (_hasFocus) {
      borderColor = ClayTokens.clayPrimary;
      labelColor = isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayPrimary;
    } else {
      borderColor = isDark ? ClayTokens.clayDarkBorderStrong : ClayTokens.clayBorder;
      labelColor = isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary;
    }

    final borderWidth = hasError ? 1.5 : 1.0;
    final focusBorderWidth = hasError ? 2.0 : 2.0;
    final radius = BorderRadius.circular(ClayTokens.radiusButton);
    final outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType ?? widget.textInputType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofocus: widget.autofocus,
      autovalidateMode: widget.autovalidateMode,
      validator: widget.validator,
      onChanged: (value) {
        if (_currentError != null) setState(() => _currentError = null);
        widget.onChanged?.call(value);
      },
      onFieldSubmitted: widget.onSubmitted,
      style: (isDark ? ClayTokens.darkBodyLarge : ClayTokens.bodyLarge)
          .copyWith(color: isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary),
      decoration: InputDecoration(
        label: widget.label != null
            ? Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  widget.label!,
                  style: (isDark ? ClayTokens.darkBodyMedium : ClayTokens.bodyMedium)
                      .copyWith(color: labelColor),
                ),
              )
            : null,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: effectiveError,
        counterText: '',
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: EdgeInsets.only(left: ClayTokens.md, right: ClayTokens.sm),
                child: IconTheme(
                  data: IconThemeData(
                    color: _hasFocus ? ClayTokens.clayPrimary : labelColor,
                    size: 20,
                  ),
                  child: widget.prefixIcon!,
                ),
              )
            : null,
        suffixIcon: widget.suffixIcon != null
            ? GestureDetector(
                onTap: widget.onSuffixTap,
                child: Padding(
                  padding: EdgeInsets.only(right: ClayTokens.md),
                  child: IconTheme(
                    data: IconThemeData(
                      color: labelColor,
                      size: 20,
                    ),
                    child: widget.suffixIcon!,
                  ),
                ),
              )
            : null,
        hintStyle: (isDark ? ClayTokens.darkBodyMedium : ClayTokens.bodyMedium)
            .copyWith(color: isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary),
        errorStyle: (isDark ? ClayTokens.darkLabelSmall : ClayTokens.labelSmall)
            .copyWith(color: ClayTokens.clayError),
        helperStyle: (isDark ? ClayTokens.darkLabelSmall : ClayTokens.labelSmall)
            .copyWith(color: isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary),
        isDense: true,
        filled: true,
        fillColor: isDark ? ClayTokens.clayDarkCard : ClayTokens.clayCard,
        contentPadding: EdgeInsets.fromLTRB(
          ClayTokens.md,
          ClayTokens.lg,
          ClayTokens.md,
          ClayTokens.sm,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: hasError ? ClayTokens.clayError : ClayTokens.clayPrimary,
            width: focusBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: ClayTokens.clayError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: ClayTokens.clayError, width: 2.0),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        alignLabelWithHint: widget.maxLines != 1,
      ),
    );
  }
}

/// Specialized input variants
class ClayTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;

  const ClayTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClayInput(
      controller: controller,
      label: label,
      hint: hint,
      errorText: errorText,
      obscureText: obscureText,
      onChanged: onChanged,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
    );
  }
}

class ClayPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ClayPasswordField({
    super.key,
    this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
  });

  @override
  State<ClayPasswordField> createState() => _ClayPasswordFieldState();
}

class _ClayPasswordFieldState extends State<ClayPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return ClayInput(
      controller: widget.controller,
      label: widget.label,
      errorText: widget.errorText,
      obscureText: _obscureText,
      onChanged: widget.onChanged,
      suffixIcon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
      onSuffixTap: () => setState(() => _obscureText = !_obscureText),
    );
  }
}

class ClaySearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const ClaySearchField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClayInput(
      controller: controller,
      hint: hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: controller?.text.isNotEmpty == true ? const Icon(Icons.clear) : null,
      onSuffixTap: onClear,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
    );
  }
}