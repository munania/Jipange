import 'package:flutter/material.dart';
import 'package:locallists/features/task/task.dart';
import 'package:locallists/utils/theme.dart';

/// Bottom sheet for choosing how a task repeats. Pops with the chosen
/// [RecurrenceRule], or null if dismissed without a change.
class RecurrencePickerSheet extends StatefulWidget {
  final RecurrenceRule current;
  final bool isDarkMode;

  const RecurrencePickerSheet({
    super.key,
    required this.current,
    required this.isDarkMode,
  });

  @override
  State<RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<RecurrencePickerSheet> {
  late RecurrenceType _selectedType;
  late int _customInterval;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.current.type;
    _customInterval =
        widget.current.type == RecurrenceType.custom ? widget.current.interval : 2;
  }

  Color get _accent => AppThemes.accentFor(widget.isDarkMode);

  void _choose(RecurrenceType type) {
    if (type == RecurrenceType.custom) {
      setState(() => _selectedType = type);
      return; // let them dial in the interval before confirming
    }
    Navigator.pop(context, RecurrenceRule(type: type));
  }

  static const _options = [
    (type: RecurrenceType.none, icon: Icons.block, label: 'None'),
    (type: RecurrenceType.daily, icon: Icons.today, label: 'Daily'),
    (type: RecurrenceType.weekly, icon: Icons.view_week, label: 'Weekly'),
    (type: RecurrenceType.monthly, icon: Icons.calendar_month, label: 'Monthly'),
    (type: RecurrenceType.custom, icon: Icons.tune, label: 'Custom interval'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Repeat',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ..._options.map((option) {
              final isSelected = _selectedType == option.type;
              return ListTile(
                leading: Icon(option.icon,
                    color: isSelected ? _accent : Colors.grey),
                title: Text(option.label),
                trailing: isSelected && option.type != RecurrenceType.custom
                    ? Icon(Icons.check, color: _accent)
                    : null,
                onTap: () => _choose(option.type),
              );
            }),
            if (_selectedType == RecurrenceType.custom) ...[
              const Divider(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Every'),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _customInterval > 1
                          ? () => setState(() => _customInterval--)
                          : null,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$_customInterval',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: _accent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _customInterval++),
                    ),
                    Text('day${_customInterval == 1 ? '' : 's'}'),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        RecurrenceRule(
                          type: RecurrenceType.custom,
                          interval: _customInterval,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
