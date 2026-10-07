import 'package:flutter/material.dart';
import '../Services/api_service.dart';
import 'brands_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> categories = [];

  int? editingCategoryId;
  bool isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  final TextEditingController todoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getCategories();
  }

  @override
  void dispose() {
    todoController.dispose();
    super.dispose();
  }

  // --- API LOGICS (UNTOUCHED) ---

  Future<void> getCategories() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get('/categories');
      if (response.statusCode != 200) {
        throw _CategoryRequestFailure(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
      final data = ApiService.decode(response);
      if (data is! List) {
        throw const FormatException('Expected a category list.');
      }
      final loaded = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        categories = loaded;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is _CategoryRequestFailure
            ? error.message
            : ApiService.messageForError(error);
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> addCategory() async {
    final name = todoController.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post(
        '/categories',
        body: ApiService.encode({'name': name}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        todoController.clear();
        await getCategories();
        if (!mounted) return;
        _showMessage('Category added successfully.');
      } else {
        _showMessage(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
    } catch (error) {
      _showMessage(ApiService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text('This category will be removed from the catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.delete('/categories/$categoryId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await getCategories();
        if (!mounted) return;
        _showMessage('Category deleted successfully.');
      } else {
        _showMessage(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
    } catch (error) {
      _showMessage(ApiService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> updateCategory(int categoryId, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.put(
        '/categories/$categoryId',
        body: ApiService.encode({'name': trimmedName}),
      );
      if (response.statusCode == 200) {
        todoController.clear();
        setState(() => editingCategoryId = null);
        await getCategories();
        if (!mounted) return;
        _showMessage('Category updated successfully.');
      } else {
        _showMessage(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
    } catch (error) {
      _showMessage(ApiService.messageForError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void cancelEditing() {
    setState(() {
      editingCategoryId = null;
      todoController.clear();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void submitCategory() {
    final name = todoController.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter a category name.');
      return;
    }
    final categoryId = editingCategoryId;
    if (categoryId == null) {
      addCategory();
    } else {
      updateCategory(categoryId, name);
    }
  }

  // Smooth Normal Transition Helper
  void _navigateToBrands(int categoryId, String categoryName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BrandsScreen(categoryId: categoryId, categoryName: categoryName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  // --- UI DESIGN & ANIMATIONS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = editingCategoryId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Categories Management",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : getCategories,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Categories',
          ),
        ],
      ),
      body: Column(
        children: [
          // Styled Input Container Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Editing Mode",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: todoController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submitCategory(),
                        decoration: InputDecoration(
                          hintText: "Enter category name...",
                          prefixIcon: const Icon(Icons.category_outlined),
                          suffixIcon: isEditing
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey,
                                  ),
                                  onPressed: cancelEditing,
                                  tooltip: "Cancel editing",
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isEditing
                                  ? Colors.orange
                                  : theme.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Add/Update Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      child: ElevatedButton(
                        onPressed: _isSaving || isLoading
                            ? null
                            : submitCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEditing
                              ? Colors.orange
                              : theme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Row(
                            key: ValueKey<bool>(isEditing),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEditing
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isEditing ? "Update" : "Add",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dynamic Body List
          Expanded(
            child: isLoading && categories.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 50,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? "No categories found",
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage == null
                              ? "Add a new category above to get started"
                              : "Check your connection and try again",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: getCategories,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: getCategories,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isBeingEdited =
                            editingCategoryId == category['id'];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isBeingEdited
                                ? Colors.orange.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isBeingEdited
                                  ? Colors.orange
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isBeingEdited
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : theme.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  (category['name'] != null &&
                                          category['name'].isNotEmpty)
                                      ? category['name'][0]
                                            .toString()
                                            .toUpperCase()
                                      : 'C',
                                  style: TextStyle(
                                    color: isBeingEdited
                                        ? Colors.orange
                                        : theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                category['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: isBeingEdited
                                          ? Colors.orange
                                          : Colors.blueGrey[400],
                                    ),
                                    tooltip: 'Edit Category',
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              editingCategoryId =
                                                  category['id'];
                                              todoController.text =
                                                  category['name'];
                                            });
                                          },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red[400],
                                    ),
                                    tooltip: 'Delete Category',
                                    onPressed: _isSaving
                                        ? null
                                        : () => deleteCategory(category['id']),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              onTap: () {
                                _navigateToBrands(
                                  category['id'],
                                  category['name'],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRequestFailure implements Exception {
  const _CategoryRequestFailure(this.message);

  final String message;
}
