import 'package:flutter/material.dart';
import 'package:locallists/data/task_database_helper.dart';
import 'package:locallists/utils/theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<Map<String, dynamic>> _categories = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF2196F3; // Default Blue
  int _selectedIcon = 0xe6f4; // Default Work Icon

  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFFF44336, // Red
    0xFF00BCD4, // Cyan
    0xFF795548, // Brown
  ];

  final List<IconData> _icons = [
    Icons.work,
    Icons.person,
    Icons.shopping_cart,
    Icons.favorite,
    Icons.home,
    Icons.school,
    Icons.fitness_center,
    Icons.flight,
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await TaskDatabaseHelper.instance.getAllCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _addOrUpdateCategory({Map<String, dynamic>? category}) async {
    if (category != null) {
      _nameController.text = category['name'];
      _selectedColor = category['color'];
      _selectedIcon = category['icon'];
    } else {
      _nameController.clear();
      _selectedColor = 0xFF2196F3;
      _selectedIcon = 0xe6f4;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(category == null ? 'New Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration:
                        const InputDecoration(labelText: 'Category Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: _selectedColor == color
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Icon'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _icons.map((icon) {
                      return IconButton(
                        icon: Icon(icon),
                        color: _selectedIcon == icon.codePoint
                            ? Color(_selectedColor)
                            : Colors.grey,
                        onPressed: () =>
                            setState(() => _selectedIcon = icon.codePoint),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final newCategory = {
                    'name': _nameController.text,
                    'color': _selectedColor,
                    'icon': _selectedIcon,
                  };

                  if (category == null) {
                    await TaskDatabaseHelper.instance
                        .createCategory(newCategory);
                  } else {
                    newCategory['id'] = category['id'];
                    await TaskDatabaseHelper.instance
                        .updateCategory(newCategory);
                  }
                  _loadCategories();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
            'Are you sure? Tasks in this category will be unassigned.'),
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
      await TaskDatabaseHelper.instance.deleteCategory(id);
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = AppThemes.accentFor(isDarkMode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(category['color']),
              child: Icon(
                IconData(category['icon'], fontFamily: 'MaterialIcons'),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(category['name']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: accent),
                  onPressed: () => _addOrUpdateCategory(category: category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCategory(category['id']),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () => _addOrUpdateCategory(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
