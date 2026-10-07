import 'package:flutter/material.dart';
import '../Services/api_service.dart';
import 'products_screen.dart';

class BrandsScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const BrandsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  List<Map<String, dynamic>> brands = [];
  int? editingBrandId;
  bool isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  final TextEditingController brandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getBrands();
  }

  @override
  void dispose() {
    brandController.dispose();
    super.dispose();
  }

  // --- API LOGICS (UNCHANGED) ---

  Future<void> getBrands() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get(
        '/brands?category_id=${widget.categoryId}',
      );
      if (response.statusCode != 200) {
        throw _BrandRequestFailure(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
      final data = ApiService.decode(response);
      if (data is! List) throw const FormatException('Expected a brand list.');
      final loaded = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        brands = loaded;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is _BrandRequestFailure
            ? error.message
            : ApiService.messageForError(error);
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> addBrand() async {
    final name = brandController.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post(
        '/brands',
        body: ApiService.encode({
          'category_id': widget.categoryId,
          'name': name,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        brandController.clear();
        await getBrands();
        if (!mounted) return;
        _showMessage('Brand added successfully.');
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

  Future<void> deleteBrand(int brandId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete brand?'),
        content: const Text('This brand will be removed from the catalog.'),
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
      final response = await ApiService.delete('/brands/$brandId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await getBrands();
        if (!mounted) return;
        _showMessage('Brand deleted successfully.');
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

  Future<void> updateBrand(int brandId, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.put(
        '/brands/$brandId',
        body: ApiService.encode({'name': trimmedName}),
      );
      if (response.statusCode == 200) {
        brandController.clear();
        setState(() => editingBrandId = null);
        await getBrands();
        if (!mounted) return;
        _showMessage('Brand updated successfully.');
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
      editingBrandId = null;
      brandController.clear();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void submitBrand() {
    final name = brandController.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter a brand name.');
      return;
    }
    final brandId = editingBrandId;
    if (brandId == null) {
      addBrand();
    } else {
      updateBrand(brandId, name);
    }
  }

  // Helper function for smooth & normal screen transitions
  void _navigateToProducts(int brandId, String brandName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProductsScreen(brandId: brandId, brandName: brandName),
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
    final isEditing = editingBrandId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              "Brands Management",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : getBrands,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Brands',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Input Card
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
                        controller: brandController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submitBrand(),
                        decoration: InputDecoration(
                          hintText: "Enter brand name...",
                          prefixIcon: const Icon(
                            Icons.branding_watermark_outlined,
                          ),
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
                        onPressed: _isSaving || isLoading ? null : submitBrand,
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

          // Dynamic Body (Loader / Empty State / List)
          Expanded(
            child: isLoading && brands.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : brands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.loyalty_outlined,
                            size: 50,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? "No brands found",
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage == null
                              ? "Add a new brand above to get started"
                              : "Check your connection and try again",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: getBrands,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: getBrands,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      itemCount: brands.length,
                      itemBuilder: (context, index) {
                        final brand = brands[index];
                        final isBeingEdited = editingBrandId == brand['id'];

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
                                  (brand['name'] != null &&
                                          brand['name'].isNotEmpty)
                                      ? brand['name'][0]
                                            .toString()
                                            .toUpperCase()
                                      : 'B',
                                  style: TextStyle(
                                    color: isBeingEdited
                                        ? Colors.orange
                                        : theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                brand['name'] ?? '',
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
                                    tooltip: 'Edit Brand',
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              editingBrandId = brand['id'];
                                              brandController.text =
                                                  brand['name'];
                                            });
                                          },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red[400],
                                    ),
                                    tooltip: 'Delete Brand',
                                    onPressed: _isSaving
                                        ? null
                                        : () => deleteBrand(brand['id']),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              onTap: () {
                                _navigateToProducts(brand['id'], brand['name']);
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

class _BrandRequestFailure implements Exception {
  const _BrandRequestFailure(this.message);

  final String message;
}
