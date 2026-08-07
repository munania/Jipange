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
  late RecurrenceUnit _customUnit;
  late TextEditingController _intervalController;
  String? _intervalError;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.current.type;
    _customUnit = widget.current.type == RecurrenceType.custom
        ? widget.current.unit
        : RecurrenceUnit.hours;
    final initialInterval =
        widget.current.type == RecurrenceType.custom ? widget.current.interval : 30;
    _intervalController =
        TextEditingController(text: initialInterval.toString());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Color get _accent => AppThemes.accentFor(widget.isDarkMode);

  void _choose(RecurrenceType type) {
    if (type == RecurrenceType.custom) {
      setState(() => _selectedType = type);
      return; // let them dial in the interval before confirming
    }
    Navigator.pop(context, RecurrenceRule(type: type));
  }

  void _confirmCustom() {
    final value = int.tryParse(_intervalController.text.trim());
    if (value == null || value <= 0) {
      setState(() => _intervalError = 'Enter a number greater than 0');
      return;
    }
    Navigator.pop(
      context,
      RecurrenceRule(
        type: RecurrenceType.custom,
        interval: value,
        unit: _customUnit,
      ),
    );
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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: SingleChildScrollView(
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
              Text(
                'Repeat',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._options.map((option) {
                final isSelected = _selectedType == option.type;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
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
                const Divider(height: 24),
                Text(
                  'Repeat every',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          errorText: _intervalError,
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _accent, width: 2),
                          ),
                        ),
                        onChanged: (_) {
                          if (_intervalError != null) {
                            setState(() => _intervalError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RecurrenceUnit.values.map((unit) {
                          final isSelected = _customUnit == unit;
                          return ChoiceChip(
                            selected: isSelected,
                            label: Text(
                              unit.label(2), // plural label for the chip
                            ),
                            selectedColor: _accent,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                            ),
                            onSelected: (_) =>
                                setState(() => _customUnit = unit),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: _confirmCustom,
                    child: const Text('Done'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
