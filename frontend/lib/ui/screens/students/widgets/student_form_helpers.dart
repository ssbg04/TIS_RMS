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
  final List<String> stepTitles;
  final ValueChanged<int>? onStepTapped;

  const ColorLineStepper({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.stepTitles,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p24,
        vertical: AppSizes.p16,
      ),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(totalSteps * 2 - 1, (index) {
              if (index.isOdd) {
                return const SizedBox(width: 8);
              }
              final idx = index ~/ 2;
              final activeOrDone = currentStep >= idx;
              final color = activeOrDone ? AppColors.primaryGreen : Colors.grey.shade300;
              final title = idx < stepTitles.length ? stepTitles[idx] : 'Step ${idx + 1}';

              return Expanded(
                child: InkWell(
                  onTap: onStepTapped != null ? () => onStepTapped!(idx) : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: title,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (stepTitles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(totalSteps * 2 - 1, (index) {
                if (index.isOdd) {
                  return const SizedBox(width: 8);
                }
                final idx = index ~/ 2;
                final isCurrent = currentStep == idx;
                final title = idx < stepTitles.length ? stepTitles[idx] : '';

                return Expanded(
                  child: InkWell(
                    onTap: onStepTapped != null ? () => onStepTapped!(idx) : null,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? AppColors.primaryGreen
                            : (currentStep > idx
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
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
          inputFormatters: [UpperCaseWordsFormatter()],
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
                separatorBuilder: (_, __) => const Divider(height: 1),
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
    String text = newValue.text.trim();
    final isoMatch = RegExp(r'^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$').firstMatch(text);
    if (isoMatch != null) {
      final yyyy = isoMatch.group(1)!;
      final mm = isoMatch.group(2)!.padLeft(2, '0');
      final dd = isoMatch.group(3)!.padLeft(2, '0');
      text = '$mm$dd$yyyy';
    } else {
      final sepMatch = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$').firstMatch(text);
      if (sepMatch != null) {
        int m = int.parse(sepMatch.group(1)!);
        int d = int.parse(sepMatch.group(2)!);
        int y = int.parse(sepMatch.group(3)!);
        if (y < 100) y += (y <= 30 ? 2000 : 1900);
        if (m > 12 && d <= 12) {
          final tmp = m;
          m = d;
          d = tmp;
        }
        final mm = m.toString().padLeft(2, '0');
        final dd = d.toString().padLeft(2, '0');
        text = '$mm$dd$y';
      }
    }

    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      buf.write(d[i]);
      if (i == 1 || i == 3) buf.write('-');
    }
    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
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
