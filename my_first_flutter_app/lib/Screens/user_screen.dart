import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/api_service.dart';
import '../Services/database_helper.dart';
import 'product_details_screen.dart';
import 'my_orders_screen.dart';
import 'package:geolocator/geolocator.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with WidgetsBindingObserver {
  bool locationActive = false;
  bool _isSyncingLocation = false;
  String? _locationMessage;
  bool _pendingLocationSettingsReturn = false;
  bool isLoadingProducts = true;
  bool _isFetchingProducts = false;
  bool _showingOfflineProducts = false;
  String? _productError;
  List<Map<String, dynamic>> products = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // --- LOCATION LOGIC (UNTOUCHED) ---
  Future<void> getCurrentLocation() async {
    if (_isSyncingLocation) return;
    setState(() {
      _isSyncingLocation = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            locationActive = false;
            _locationMessage =
                'Turn on location services to share your location.';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            locationActive = false;
            _locationMessage = permission == LocationPermission.deniedForever
                ? 'Allow location access in your device settings.'
                : 'Location permission was not granted.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final response = await ApiService.post(
        '/location',
        body: ApiService.encode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (!mounted) return;
      setState(() {
        locationActive = response.statusCode == 200;
        if (!locationActive) {
          _locationMessage = ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        locationActive = false;
        _locationMessage = ApiService.messageForError(error);
      });
    } finally {
      if (mounted) setState(() => _isSyncingLocation = false);
    }
  }

  Future<void> openLocationSettings() async {
    _pendingLocationSettingsReturn = true;
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      _pendingLocationSettingsReturn = false;
      if (mounted) {
        setState(() {
          _locationMessage = 'Unable to open your device location settings.';
        });
      }
    }
  }

  // --- LOGOUT LOGIC (UNTOUCHED) ---
  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // --- PRODUCTS API LOGIC (UNTOUCHED) ---
  Future<void> getProducts() async {
    if (_isFetchingProducts) return;
    _isFetchingProducts = true;
    if (mounted) setState(() => isLoadingProducts = true);

    try {
      final response = await ApiService.get('/all-products');
      if (response.statusCode != 200) {
        throw _ProductListRequestFailure(
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
      final loadedProducts = data
          .whereType<Map>()
          .map((product) => Map<String, dynamic>.from(product))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        products = loadedProducts;
        _showingOfflineProducts = false;
        _productError = null;
      });
      try {
        await _databaseHelper.replaceAllProducts(loadedProducts);
      } catch (_) {
        // Keep the successful live response even if local storage is unavailable.
      }
    } catch (error) {
      try {
        final cachedProducts = await _databaseHelper
            .fetchAllProductsFromLocal();
        if (!mounted) return;
        setState(() {
          products = cachedProducts;
          _showingOfflineProducts = cachedProducts.isNotEmpty;
          _productError = cachedProducts.isEmpty
              ? error is _ProductListRequestFailure
                    ? error.message
                    : ApiService.messageForError(error)
              : null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          products = [];
          _showingOfflineProducts = false;
          _productError = error is _ProductListRequestFailure
              ? error.message
              : ApiService.messageForError(error);
        });
      }
    } finally {
      _isFetchingProducts = false;
      if (mounted) setState(() => isLoadingProducts = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getProducts();
    getCurrentLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingLocationSettingsReturn) {
      _pendingLocationSettingsReturn = false;
      getCurrentLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,
        title: const Text(
          "Marketplace",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await getProducts();
          await getCurrentLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withBlue(220),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Explore active products and manage your orders",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // LOCATION STATUS CARD
              InkWell(
                onTap: _isSyncingLocation
                    ? null
                    : locationActive
                    ? getCurrentLocation
                    : openLocationSettings,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: locationActive
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: locationActive
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: locationActive
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          locationActive
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          color: locationActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSyncingLocation
                                  ? 'Syncing location'
                                  : locationActive
                                  ? 'Location active'
                                  : 'Location unavailable',
                              style: TextStyle(
                                color: locationActive
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _locationMessage ??
                                  (locationActive
                                      ? 'Tap to update your shared location'
                                      : 'Tap to review location settings'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: locationActive
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSyncingLocation)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          locationActive
                              ? Icons.refresh_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: locationActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // DASHBOARD ACTION TILES (Profile, Products Count, My Orders)
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      icon: Icons.person_rounded,
                      title: "My Profile",
                      subtitle: "Account Details",
                      color: Colors.blue,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDashboardCard(
                      icon: Icons.receipt_long_rounded,
                      title: "My Orders",
                      subtitle: "Track Status",
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyOrdersScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECTION HEADER FOR PRODUCTS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 22,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Available Products",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${products.length} Items",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (_showingOfflineProducts)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Showing saved products while you are offline.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),

              // PRODUCTS GRID / LIST
              if (isLoadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (products.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _productError ?? 'No products available right now',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (_productError != null) ...[
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
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 640
                        ? 4
                        : constraints.maxWidth >= 440
                        ? 3
                        : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 2 ? 0.82 : 0.92,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final String name =
                            product['name']?.toString() ?? 'Unnamed Product';
                        final String price =
                            product['price']?.toString() ?? '0';
                        final String quantity =
                            product['quantity']?.toString() ?? '0';

                        return Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProductDetailsScreen(product: product),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Thumbnail Box
                                  // Product Image
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: product['image'] != null &&
                                          product['image'].toString().isNotEmpty
                                          ? Image.network(
                                        product['image'].toString().replaceFirst(
                                          '127.0.0.1',
                                          '192.168.18.7',
                                        ),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: double.infinity,
                                            color: Colors.grey[100],
                                            child: Icon(
                                              Icons.image_not_supported_outlined,
                                              size: 40,
                                              color: theme.primaryColor,
                                            ),
                                          );
                                        },
                                      )
                                          : Container(
                                        width: double.infinity,
                                        color: Colors.grey[100],
                                        child: Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 40,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Product Title
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // Stock Quantity Tag
                                  Text(
                                    "Stock: $quantity left",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Price Tag & Navigation Arrow
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Rs. $price",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withAlpha(
                                            20,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Dashboard Quick Action Helper Card
  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductListRequestFailure implements Exception {
  const _ProductListRequestFailure(this.message);

  final String message;
}
