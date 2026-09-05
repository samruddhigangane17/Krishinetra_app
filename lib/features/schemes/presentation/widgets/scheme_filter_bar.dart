import 'package:flutter/material.dart';

import 'package:krishinetra/core/theme/app_theme.dart';
import 'package:krishinetra/features/schemes/domain/models/scheme.dart';

/// Search bar + category filter chips + government-level filter chips for
/// the schemes screen.
///
/// **Note on "filter by state":** this dataset is Maharashtra-only — every
/// row is already scoped to one Indian state, so there's no per-scheme
/// state field to filter *by* (see the dataset review). The closest real
/// field is [Scheme.government] (Central / State / Central-State), which
/// this widget exposes as the second filter row instead. If/when more
/// states are added to the dataset, a true state filter can slot in here
/// alongside this one.
class SchemeFilterBar extends StatelessWidget {
  const SchemeFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedGovernment,
    required this.onGovernmentChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  /// Null means "All categories".
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  /// Null means "All"; otherwise one of `Central` / `State` / `Central/State`.
  final String? selectedGovernment;
  final ValueChanged<String?> onGovernmentChanged;

  static const List<String> _governmentOptions = ['Central', 'State', 'Central/State'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search schemes by name, keyword, or department…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 14),

        // Category filter chips
        Text('Category', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedCategory == null,
                onTap: () => onCategoryChanged(null),
              ),
              for (final String category in SchemeCategories.all) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: SchemeCategories.shortLabel(category),
                  selected: selectedCategory == category,
                  onTap: () => onCategoryChanged(selectedCategory == category ? null : category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Government-level filter chips
        Text('Government', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedGovernment == null,
                onTap: () => onGovernmentChanged(null),
              ),
              for (final String gov in _governmentOptions) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: gov,
                  selected: selectedGovernment == gov,
                  onTap: () => onGovernmentChanged(selectedGovernment == gov ? null : gov),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant.withOpacity(.7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
