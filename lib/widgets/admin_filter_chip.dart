import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable filter chip widget for Admin Center
/// Provides consistent filter chip styling with selection state
class AdminFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final Color? selectedColor;

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppTheme.colorsOf(context).textColorLight,
            ),
            SizedBox(width: AppTheme.spacingXS),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected ? Colors.white : AppTheme.colorsOf(context).textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppTheme.colorsOf(context).backgroundCard,
      selectedColor: selectedColor ?? AppTheme.colorsOf(context).primary,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected
            ? (selectedColor ?? AppTheme.colorsOf(context).primary)
            : AppTheme.colorsOf(context).secondary.withValues(alpha: 0.3),
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      showCheckmark: false,
    );
  }
}

/// Dropdown filter widget for Admin Center
/// Provides consistent dropdown styling for filter options
class AdminDropdownFilter<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final Function(T?) onChanged;
  final String? hint;

  const AdminDropdownFilter({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.colorsOf(context).textColorLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppTheme.spacingXS),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          hint: hint != null
              ? Text(
                  hint!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight,
                  ),
                )
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.colorsOf(context).backgroundCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.colorsOf(context).secondary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.colorsOf(context).secondary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              borderSide: BorderSide(
                color: AppTheme.colorsOf(context).primary,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
          ),
          dropdownColor: AppTheme.colorsOf(context).backgroundCard,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
