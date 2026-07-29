import 'package:flutter/material.dart';
import 'package:locallists/features/lists/homepage.dart' show SortOption;
import 'package:locallists/utils/theme.dart';

class FilterBottomSheet extends StatefulWidget {
  final Map<int, Map<String, dynamic>> categoriesMap;
  final SortOption currentSort;
  final Set<int> selectedCategoryIds;
  final bool showCompleted;
  final ValueChanged<SortOption> onSortChanged;
  final ValueChanged<Set<int>> onCategoriesChanged;
  final ValueChanged<bool> onShowCompletedChanged;
  final bool isDarkMode;

  const FilterBottomSheet({
    super.key,
    required this.categoriesMap,
    required this.currentSort,
    required this.selectedCategoryIds,
    required this.showCompleted,
    required this.onSortChanged,
    required this.onCategoriesChanged,
    required this.onShowCompletedChanged,
    required this.isDarkMode,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late SortOption _sort;
  late Set<int> _categoryIds;
  late bool _showCompleted;

  static const _sortLabels = {
    SortOption.custom: 'Custom Order',
    SortOption.dateCreated: 'Date Created (Newest)',
    SortOption.dueDate: 'Due Date (Soonest)',
    SortOption.alphabetical: 'Alphabetical (A-Z)',
  };

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _categoryIds = {...widget.selectedCategoryIds};
    _showCompleted = widget.showCompleted;
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
                        _showCompleted = true;
                      });
                      widget.onSortChanged(_sort);
                      widget.onCategoriesChanged(_categoryIds);
                      widget.onShowCompletedChanged(_showCompleted);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Show/hide completed tasks
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _showCompleted ? Icons.visibility : Icons.visibility_off,
                  color: accentColor,
                ),
                title: const Text('Show finished tasks'),
                value: _showCompleted,
                onChanged: (value) {
                  setState(() => _showCompleted = value);
                  widget.onShowCompletedChanged(value);
                },
              ),

              const Divider(height: 24),

              // Sort by
              Text(
                'Sort by',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._sortLabels.entries.map((entry) {
                return RadioListTile<SortOption>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: accentColor,
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _sort,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                    widget.onSortChanged(value);
                  },
                );
              }),

              const Divider(height: 24),

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
