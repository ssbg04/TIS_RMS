import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/theme_extension.dart';

class FilterDropdownSection<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;

  const FilterDropdownSection({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.p4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              icon: Icon(
                icon ?? Icons.arrow_drop_down_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              isExpanded: true,
              dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FilterChipGroup<T> extends StatelessWidget {
  final List<T> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final String Function(T option) labelBuilder;

  const FilterChipGroup({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Wrap(
      spacing: AppSizes.p8,
      runSpacing: AppSizes.p8,
      children: options.map((option) {
        final isSelected = option == selectedValue;
        return ChoiceChip(
          label: Text(labelBuilder(option)),
          selected: isSelected,
          onSelected: (_) => onSelected(option),
          selectedColor: AppColors.primaryGreen,
          backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.inputBackground,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkBorder : AppColors.borderLight),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
          ),
        );
      }).toList(),
    );
  }
}
