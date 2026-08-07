import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/utils/theme.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  List<Map<String, dynamic>> _templates = [];
  Map<int, Map<String, dynamic>> _categoriesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await TaskDatabaseHelper.instance.getAllTemplates();
    final categories = await TaskDatabaseHelper.instance.getAllCategories();
    setState(() {
      _templates = templates;
      _categoriesMap = {for (var c in categories) c['id']: c};
      _isLoading = false;
    });
  }

  Future<void> _deleteTemplate(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TaskDatabaseHelper.instance.deleteTemplate(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemes.accentFor(isDarkMode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Templates'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined,
                            size: 40,
                            color: isDarkMode
                                ? AppThemes.darkTextSecondary
                                : AppThemes.lightTextSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No templates yet. Save one from the '
                          'add-task sheet to reuse it later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode
                                ? AppThemes.darkTextSecondary
                                : AppThemes.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    final category = _categoriesMap[template['category_id']];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Icon(Icons.description, color: accent),
                      ),
                      title: Text(template['name']),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              template['title'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (category != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              IconData(category['icon'],
                                  fontFamily: 'MaterialIcons'),
                              size: 12,
                              color: Color(category['color']),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTemplate(template['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
