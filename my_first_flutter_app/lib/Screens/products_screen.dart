import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../Services/api_service.dart';
import '../Services/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductsScreen extends StatefulWidget {
  final int brandId;
  final String brandName;

  const ProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> products = [];

  int? editingProductId;
  bool isLoading = false;
  bool _isFetchingProducts = false;
  String? _errorMessage;
  String? _offlineMessage;

  final DatabaseHelper dbHelper = DatabaseHelper();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? selectedImage;

  final TextEditingController productController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getProducts();
  }

  @override
  void dispose() {
    productController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> pickProductImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) {
        return;
      }

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      _showMessage('Image select error: $e');
    }
  }

  // ============================================================
  // GET PRODUCTS
  // API ONLINE → SAVE TO SQLITE
  // API FAIL/OFFLINE → LOAD FROM SQLITE
  // ============================================================

  Future<void> getProducts() async {
    if (_isFetchingProducts) return;
    _isFetchingProducts = true;

    if (!mounted) return;
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _offlineMessage = null;
    });

    try {
      final response = await ApiService.get(
        '/products?brand_id=${widget.brandId}',
      );

      if (response.statusCode != 200) {
        throw _ProductRequestFailure(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }

      final data = ApiService.decode(response);
      if (data is! List) {
        throw const FormatException('Expected a product list.');
      }

      final apiProducts = data
          .whereType<Map>()
          .map((product) => Map<String, dynamic>.from(product))
          .toList(growable: false);

      if (!mounted) return;
      setState(() => products = apiProducts);

      try {
        await dbHelper.replaceProductsForBrand(widget.brandId, apiProducts);
      } catch (_) {
        // The live API remains usable when local storage is unavailable.
      }
    } catch (error) {
      try {
        final localProducts = await dbHelper.fetchProductsFromLocal(
          widget.brandId,
        );
        if (!mounted) return;
        setState(() {
          products = localProducts;
          _offlineMessage = localProducts.isEmpty
              ? null
              : 'Showing saved products while the service is unavailable.';
          _errorMessage = localProducts.isEmpty
              ? error is _ProductRequestFailure
                    ? error.message
                    : ApiService.messageForError(error)
              : null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          products = [];
          _errorMessage = error is _ProductRequestFailure
              ? error.message
              : ApiService.messageForError(error);
        });
      }
    } finally {
      _isFetchingProducts = false;
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  // ADD PRODUCT
  // ============================================================

  Future<void> addProduct() async {
    final price = double.tryParse(priceController.text.trim());
    final quantity = int.tryParse(quantityController.text.trim());

    if (productController.text.trim().isEmpty ||
        price == null ||
        price < 0 ||
        quantity == null ||
        quantity < 0) {
      _showMessage(
        'Enter a product name, a valid price, and a valid quantity.',
      );
      return;
    }

    if (selectedImage == null) {
      _showMessage('Please select a product image.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/products'),
      );

      request.headers['Accept'] = 'application/json';

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['brand_id'] = widget.brandId.toString();
      request.fields['name'] = productController.text.trim();
      request.fields['price'] = price.toString();
      request.fields['quantity'] = quantity.toString();
      request.fields['description'] = '';

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          selectedImage!.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        productController.clear();
        priceController.clear();
        quantityController.clear();

        setState(() {
          selectedImage = null;
        });

        await getProducts();

        if (!mounted) return;
        _showMessage('Product added successfully.');
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
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  // DELETE PRODUCT
  // ============================================================

  Future<void> deleteProduct(int productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This product will be removed from the catalog.'),
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
    if (confirmed != true || !mounted) return;

    setState(() => isLoading = true);
    try {
      final response = await ApiService.delete('/products/$productId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await getProducts();
        if (!mounted) return;
        _showMessage('Product deleted successfully.');
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
      if (mounted) setState(() => isLoading = false);
    }
  }
  // UPDATE PRODUCT
  // ============================================================
  Future<void> updateProduct(
      int productId,
      String name,
      double price,
      int quantity,
      ) async {
    if (name.trim().isEmpty || price < 0 || quantity < 0) {
      _showMessage(
        'Enter a product name, a valid price, and a valid quantity.',
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/products/$productId'),
      );

      request.headers['Accept'] = 'application/json';

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Laravel PUT ko MultipartRequest ke saath handle karne ke liye
      request.fields['_method'] = 'PUT';

      request.fields['name'] = name.trim();
      request.fields['price'] = price.toString();
      request.fields['quantity'] = quantity.toString();
      request.fields['description'] = '';

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            selectedImage!.path,
          ),
        );
      }

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200) {
        productController.clear();
        priceController.clear();
        quantityController.clear();

        setState(() {
          editingProductId = null;
          selectedImage = null;
        });

        await getProducts();

        if (!mounted) return;

        _showMessage('Product updated successfully.');
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
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void submitProduct() {
    final price = double.tryParse(priceController.text.trim());
    final quantity = int.tryParse(quantityController.text.trim());
    if (productController.text.trim().isEmpty ||
        price == null ||
        price < 0 ||
        quantity == null ||
        quantity < 0) {
      _showMessage(
        'Enter a product name, a valid price, and a valid quantity.',
      );
      return;
    }

    final productId = editingProductId;
    if (productId == null) {
      addProduct();
    } else {
      updateProduct(productId, productController.text.trim(), price, quantity);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
  // CANCEL EDITING
  // ============================================================

  void cancelEditing() {
    setState(() {
      editingProductId = null;
      productController.clear();
      priceController.clear();
      quantityController.clear();
    });
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = editingProductId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,

        title: Text(
          widget.brandName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            onPressed: getProducts,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Products",
          ),
        ],
      ),

      body: Column(
        children: [
          // ====================================================
          // FORM CARD
          // ====================================================
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
                // FORM TITLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Text(
                      isEditing ? "Edit Product" : "Add New Product",

                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isEditing ? Colors.orange : theme.primaryColor,
                      ),
                    ),

                    if (isEditing)
                      GestureDetector(
                        onTap: cancelEditing,

                        child: const Row(
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),

                            SizedBox(width: 4),

                            Text(
                              "Cancel",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

// PRODUCT IMAGE
                GestureDetector(
                  onTap: pickProductImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: selectedImage == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select Product Image',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(selectedImage!.path),
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

// PRODUCT NAME
                TextField(
                  controller: productController,

                  decoration: InputDecoration(
                    hintText: "Product Name",

                    prefixIcon: const Icon(Icons.shopping_bag_outlined),

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
                        color: isEditing ? Colors.orange : theme.primaryColor,

                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // PRICE + QUANTITY
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,

                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),

                        decoration: InputDecoration(
                          hintText: "Price",

                          prefixIcon: const Icon(Icons.currency_rupee),

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

                    const SizedBox(width: 10),

                    Expanded(
                      child: TextField(
                        controller: quantityController,

                        keyboardType: TextInputType.number,

                        decoration: InputDecoration(
                          hintText: "Quantity",

                          prefixIcon: const Icon(Icons.inventory_2_outlined),

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
                  ],
                ),

                const SizedBox(height: 12),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : submitProduct,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEditing
                          ? Colors.orange
                          : theme.primaryColor,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),

                      elevation: 2,
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          isEditing
                              ? Icons.check_circle_outline
                              : Icons.add_rounded,

                          color: Colors.white,
                          size: 20,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          isEditing ? "Update Product" : "Add Product",

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_offlineMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _offlineMessage!,
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                ),
              ),
            ),

          // ====================================================
          // PRODUCT LIST
          // ====================================================
          Expanded(
            child: isLoading && products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.inventory_outlined,
                          size: 70,
                          color: Colors.grey[400],
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _errorMessage ?? 'No products found for this brand',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: getProducts,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: getProducts,

                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),

                      itemCount: products.length,

                      itemBuilder: (context, index) {
                        final product = products[index];

                        final isBeingEdited = editingProductId == product['id'];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),

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

                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),

                            child: Row(
                              children: [
                                // PRODUCT ICON
                                // PRODUCT IMAGE
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: product['image'] != null &&
                                      product['image'].toString().isNotEmpty
                                      ? Image.network(
                                    product['image'].toString().replaceFirst(
                                      '127.0.0.1',
                                      '192.168.18.7',
                                    ),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey.shade100,
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  )
                                      : Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.grey.shade100,
                                    child: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // PRODUCT DETAILS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        product['name'].toString(),

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,

                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,

                                        children: [
                                          // PRICE
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),

                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,

                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),

                                            child: Text(
                                              "Rs. ${product['price']}",

                                              style: TextStyle(
                                                color: Colors.green.shade700,

                                                fontWeight: FontWeight.bold,

                                                fontSize: 12,
                                              ),
                                            ),
                                          ),

                                          // QUANTITY
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),

                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,

                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),

                                            child: Text(
                                              "Qty: ${product['quantity']}",

                                              style: TextStyle(
                                                color: Colors.blue.shade700,

                                                fontWeight: FontWeight.bold,

                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // ACTIONS
                                Row(
                                  mainAxisSize: MainAxisSize.min,

                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,

                                        color: isBeingEdited
                                            ? Colors.orange
                                            : Colors.blueGrey[400],
                                      ),

                                      onPressed: () {
                                        setState(() {
                                          editingProductId = product['id'];

                                          productController.text =
                                              product['name'].toString();

                                          priceController.text =
                                              product['price'].toString();

                                          quantityController.text =
                                              product['quantity'].toString();

                                          selectedImage = null;
                                        });
                                      },
                                    ),

                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,

                                        color: Colors.red[400],
                                      ),

                                      onPressed: () =>
                                          deleteProduct(product['id']),
                                    ),
                                  ],
                                ),
                              ],
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

class _ProductRequestFailure implements Exception {
  const _ProductRequestFailure(this.message);

  final String message;
}
