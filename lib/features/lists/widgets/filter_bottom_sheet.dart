import 'package:flutter/material.dart';
import 'package:locallists/features/lists/homepage.dart' show SortOption;
import 'package:locallists/utils/theme.dart';

class FilterBottomSheet extends StatefulWidget {
  final Map<int, Map<String, dynamic>> categoriesMap;
  final SortOption currentSort;
  final Set<int> selectedCategoryIds;
  final ValueChanged<SortOption> onSortChanged;
  final ValueChanged<Set<int>> onCategoriesChanged;
  final bool isDarkMode;

  const FilterBottomSheet({
    super.key,
    required this.categoriesMap,
    required this.currentSort,
    required this.selectedCategoryIds,
    required this.onSortChanged,
    required this.onCategoriesChanged,
    required this.isDarkMode,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late SortOption _sort;
  late Set<int> _categoryIds;

  static const _sortLabels = {
    SortOption.custom: 'Custom Order',
    SortOption.dateCreated: 'Date Created',
    SortOption.dueDate: 'Due Date',
    SortOption.alphabetical: 'Alphabetical',
  };

  static const _sortIcons = {
    SortOption.custom: Icons.drag_indicator,
    SortOption.dateCreated: Icons.schedule,
    SortOption.dueDate: Icons.event,
    SortOption.alphabetical: Icons.sort_by_alpha,
  };

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _categoryIds = {...widget.selectedCategoryIds};
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isDarkMode ? AppThemes.lightSecondary : AppThemes.darkPrimary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _sort = SortOption.custom;
                        _categoryIds = {};
                      });
                      widget.onSortChanged(_sort);
                      widget.onCategoriesChanged(_categoryIds);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sort by - chip style, matching the category filter below
              Text(
                'Sort by',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sortLabels.entries.map((entry) {
                  final isSelected = _sort == entry.key;
                  return ChoiceChip(
                    selected: isSelected,
                    avatar: Icon(
                      _sortIcons[entry.key],
                      size: 16,
                      color: isSelected ? Colors.white : accentColor,
                    ),
                    label: Text(entry.value),
                    selectedColor: accentColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                    ),
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _sort = entry.key);
                      widget.onSortChanged(entry.key);
                    },
                  );
                }).toList(),
              ),

              const Divider(height: 32),

              // Filter by category
              Text(
                'Filter by category',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (widget.categoriesMap.isEmpty)
                const Text(
                  'No categories yet. Create one from Settings > Manage Categories.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categoriesMap.values.map((category) {
                    final isSelected = _categoryIds.contains(category['id']);
                    return FilterChip(
                      selected: isSelected,
                      avatar: Icon(
                        IconData(category['icon'], fontFamily: 'MaterialIcons'),
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : Color(category['color']),
                      ),
                      label: Text(category['name']),
                      selectedColor: Color(category['color']),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _categoryIds.add(category['id']);
                          } else {
                            _categoryIds.remove(category['id']);
                          }
                        });
                        widget.onCategoriesChanged(_categoryIds);
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
