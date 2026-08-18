import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

// ================================================================
// AUTO-CAPITALISE FIRST LETTER OF EVERY WORD
// ================================================================
class UpperCaseWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

// ================================================================
// COLOR LINE STEPPER (Sleek Horizontal Bars, No Numbers/Text)
// ================================================================
class ColorLineStepper extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const ColorLineStepper({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p24,
        vertical: AppSizes.p16,
      ),
      color: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            return const SizedBox(width: 8);
          }
          final idx = index ~/ 2;
          final activeOrDone = currentStep >= idx;
          final color = activeOrDone
              ? AppColors.primaryGreen
              : (isDark ? AppColors.darkBorder : Colors.grey.shade300);

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ================================================================
// ERROR BANNER
// ================================================================
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECTION LABEL
// ================================================================
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, thickness: 1)),
      ],
    );
  }
}

// ================================================================
// EXTENSION NAME FIELD
// ================================================================
class ExtensionNameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;

  const ExtensionNameField({
    super.key,
    required this.controller,
    required this.suggestions,
  });

  @override
  State<ExtensionNameField> createState() => _ExtensionNameFieldState();
}

class _ExtensionNameFieldState extends State<ExtensionNameField> {
  TextEditingController? _fieldController;

  void _onFieldControllerChanged() {
    if (_fieldController == null) return;
    final upper = _fieldController!.text.toUpperCase();
    if (widget.controller.text != upper) {
      widget.controller.text = upper;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: upper.length),
      );
    }
  }

  @override
  void dispose() {
    _fieldController?.removeListener(_onFieldControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toUpperCase();
        if (query.isEmpty) return widget.suggestions;
        return widget.suggestions.where((s) => s.toUpperCase().startsWith(query));
      },
      fieldViewBuilder: (ctx, fieldController, focusNode, onSubmit) {
        if (_fieldController != fieldController) {
          _fieldController?.removeListener(_onFieldControllerChanged);
          _fieldController = fieldController;
          _fieldController?.addListener(_onFieldControllerChanged);
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            UpperCaseWordsFormatter(),
            FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
          ],
          decoration: const InputDecoration(
            labelText: 'SUFFIX (Optional)',
            hintText: 'Jr. / III',
          ),
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
      onSelected: (selection) {
        if (selection == 'N/A') {
          widget.controller.clear();
          _fieldController?.clear();
        } else {
          final upper = selection.toUpperCase();
          widget.controller.text = upper;
          _fieldController?.text = upper;
        }
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final opt = options.elementAt(index);
                  final isNa = opt == 'N/A';
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isNa ? AppColors.textSecondary : null,
                          fontStyle: isNa ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// DOB INPUT FORMATTER
// ================================================================
class DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Handle backspace / deletion
    if (newValue.text.length < oldValue.text.length) {
      // If user hit backspace on a hyphen, step back one more character
      if (oldValue.selection.baseOffset > 1 &&
          oldValue.text[oldValue.selection.baseOffset - 1] == '-' &&
          newValue.selection.baseOffset == oldValue.selection.baseOffset - 1) {
        final cursor = oldValue.selection.baseOffset - 1;
        final digitsBefore = oldValue.text.substring(0, cursor).replaceAll(RegExp(r'[^\d]'), '');
        final truncatedDigitsBefore = digitsBefore.isNotEmpty ? digitsBefore.substring(0, digitsBefore.length - 1) : '';
        final digitsAfter = oldValue.text.substring(cursor + 1).replaceAll(RegExp(r'[^\d]'), '');
        final newDigits = truncatedDigitsBefore + digitsAfter;
        return _formatDigits(newDigits, cursor - 1);
      }
      final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
      return _formatDigits(digits, newValue.selection.baseOffset);
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final cleanDigits = digits.length > 8 ? digits.substring(0, 8) : digits;
    return _formatDigits(cleanDigits, null);
  }

  static TextEditingValue _formatDigits(String digits, int? desiredOffset) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) {
        buf.write('-');
      }
      buf.write(digits[i]);
    }
    final text = buf.toString();
    final offset = desiredOffset != null
        ? desiredOffset.clamp(0, text.length)
        : text.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

// ================================================================
// DOB PICKER
// ================================================================
class DobPicker extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;

  const DobPicker({super.key, this.initialDate, required this.onChanged});

  @override
  State<DobPicker> createState() => _DobPickerState();
}

class _DobPickerState extends State<DobPicker> {
  late final TextEditingController _ctrl;
  DateTime? _lastParsedDate;

  static String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.year}';

  @override
  void initState() {
    super.initState();
    _lastParsedDate = widget.initialDate;
    _ctrl = TextEditingController(
      text: widget.initialDate != null ? _fmt(widget.initialDate!) : '',
    );
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant DobPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != _lastParsedDate) {
      _lastParsedDate = widget.initialDate;
      final newText = widget.initialDate != null ? _fmt(widget.initialDate!) : '';
      if (_ctrl.text != newText) {
        _ctrl.removeListener(_onTextChanged);
        _ctrl.text = newText;
        _ctrl.addListener(_onTextChanged);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() => _parseAndNotify();

  String get _rawDigits => _ctrl.text.replaceAll('-', '');

  int _maxDayForMonth(int month, int? year) {
    if (month == 2) {
      if (year != null && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) {
        return 29;
      }
      return 28;
    }
    if ([4, 6, 9, 11].contains(month)) return 30;
    return 31;
  }

  void _parseAndNotify() {
    final raw = _rawDigits;
    DateTime? parsed;
    if (raw.length == 8) {
      final mm   = int.tryParse(raw.substring(0, 2));
      final dd   = int.tryParse(raw.substring(2, 4));
      final yyyy = int.tryParse(raw.substring(4, 8));
      final now  = DateTime.now().year;
      if (mm != null && dd != null && yyyy != null &&
          mm >= 1 && mm <= 12 &&
          dd >= 1 && dd <= _maxDayForMonth(mm, yyyy) &&
          yyyy >= 1900 && yyyy <= now) {
        parsed = DateTime(yyyy, mm, dd);
      }
    }
    _lastParsedDate = parsed;
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [DobInputFormatter()],
      style: const TextStyle(fontSize: 14, letterSpacing: 0.5),
      decoration: InputDecoration(
        labelText: 'DATE OF BIRTH (Optional)',
        hintText: 'MM-DD-YYYY',
        prefixIcon: const Icon(
          Icons.cake_outlined,
          color: AppColors.textSecondary,
        ),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged(null);
                },
              )
            : null,
      ),
    );
  }
}
