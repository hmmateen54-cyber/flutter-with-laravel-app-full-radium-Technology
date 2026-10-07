import 'package:flutter/material.dart';
import '../Services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;
  bool _isFetchingOrders = false;
  String? _errorMessage;
  final Set<int> _updatingOrderIds = {};

  static const _orderStatuses = <String>[
    'pending',
    'confirmed',
    'processing',
    'dispatched',
    'delivered',
    'cancelled',
  ];

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- API LOGIC (UNTOUCHED) ---

  Future<void> getOrders() async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get('/orders');
      if (response.statusCode != 200) {
        throw _OrdersRequestFailure(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }
      final data = ApiService.decode(response);
      if (data is! List) throw const FormatException('Expected an order list.');
      if (!mounted) return;
      setState(() {
        orders = data;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is _OrdersRequestFailure
            ? error.message
            : ApiService.messageForError(error);
      });
    } finally {
      _isFetchingOrders = false;
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    if (_updatingOrderIds.contains(orderId)) return;
    setState(() => _updatingOrderIds.add(orderId));
    try {
      final response = await ApiService.put(
        '/orders/$orderId/status',
        body: ApiService.encode({'status': status}),
      );
      if (response.statusCode == 200) {
        await getOrders();
        if (!mounted) return;
        _showMessage('Order status updated.');
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
      if (mounted) setState(() => _updatingOrderIds.remove(orderId));
    }
  }

  @override
  void initState() {
    super.initState();
    getOrders();
  }

  // Helper function for status styling
  Map<String, dynamic> _getStatusConfig(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered':
      case 'confirmed':
        return {
          'color': Colors.green.shade700,
          'bgColor': Colors.green.shade50,
          'icon': Icons.check_circle_outline,
        };
      case 'pending':
        return {
          'color': Colors.orange.shade800,
          'bgColor': Colors.orange.shade50,
          'icon': Icons.hourglass_empty_rounded,
        };
      case 'processing':
      case 'dispatched':
        return {
          'color': Colors.blue.shade700,
          'bgColor': Colors.blue.shade50,
          'icon': Icons.local_shipping_outlined,
        };
      case 'cancelled':
        return {
          'color': Colors.red.shade700,
          'bgColor': Colors.red.shade50,
          'icon': Icons.cancel_outlined,
        };
      default:
        return {
          'color': Colors.grey.shade700,
          'bgColor': Colors.grey.shade100,
          'icon': Icons.info_outline,
        };
    }
  }

  // --- UI DESIGN & ANIMATIONS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Manage Orders",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Orders",
            onPressed: isLoading ? null : getOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isLoading
            ? Center(
                key: const ValueKey("loading"),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Loading all orders...",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : orders.isEmpty
            ? Center(
                key: const ValueKey("empty"),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage ?? "No orders found",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage == null
                            ? "There are no customer orders in the system right now."
                            : "Check your connection and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: getOrders,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: getOrders,
                child: ListView.builder(
                  key: const ValueKey("list"),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final statusConfig = _getStatusConfig(
                      order['status']?.toString(),
                    );
                    final currentStatus = order['status']?.toString();
                    final selectedStatus =
                        _orderStatuses.contains(currentStatus)
                        ? currentStatus
                        : null;
                    final orderItems = order['items'] is List
                        ? order['items'] as List
                        : const <dynamic>[];

                    return Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order ID & Current Status Pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_outlined,
                                          size: 20,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Order #${order['id']}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusConfig['bgColor'],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusConfig['icon'],
                                        size: 14,
                                        color: statusConfig['color'],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${order['status'] ?? 'pending'}"
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusConfig['color'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),

                            // Customer Shipping Details
                            _buildDetailRow(
                              icon: Icons.person_outline,
                              label: "Customer",
                              value: "${order['customer_name'] ?? 'N/A'}",
                            ),
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              icon: Icons.phone_outlined,
                              label: "Phone",
                              value: "${order['phone'] ?? 'N/A'}",
                            ),
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              icon: Icons.location_city_outlined,
                              label: "City",
                              value: "${order['city'] ?? 'N/A'}",
                            ),
                            const SizedBox(height: 6),
                            _buildDetailRow(
                              icon: Icons.home_outlined,
                              label: "Address",
                              value: "${order['address'] ?? 'N/A'}",
                            ),
                            if (order['created_at'] != null) ...[
                              const SizedBox(height: 6),
                              _buildDetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: "Order Date",
                                value: "${order['created_at']}",
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),

                            // Products Breakdown Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 16,
                                        color: Colors.black87,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Ordered Items",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (orderItems.isNotEmpty)
                                    ...orderItems.map<Widget>((item) {
                                      final itemData = item is Map
                                          ? Map<String, dynamic>.from(item)
                                          : <String, dynamic>{};
                                      final productData =
                                          itemData['product'] is Map
                                          ? Map<String, dynamic>.from(
                                              itemData['product'] as Map,
                                            )
                                          : <String, dynamic>{};
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${productData['name'] ?? 'Item'} x ${itemData['quantity'] ?? 0}",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              "Rs. ${itemData['price'] ?? 0}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                  else
                                    Text(
                                      "No items found",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Total Price Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total Amount",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    "Rs. ${order['total_amount']}",
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),

                            // Order Status Control Dropdown
                            const Text(
                              "Update Order Status",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  hint: Text(
                                    currentStatus?.toUpperCase() ??
                                        'Choose status',
                                  ),
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text("Pending"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'confirmed',
                                      child: Text("Confirmed"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'processing',
                                      child: Text("Processing"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'dispatched',
                                      child: Text("Dispatched"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'delivered',
                                      child: Text("Delivered"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cancelled',
                                      child: Text("Cancelled"),
                                    ),
                                  ],
                                  onChanged:
                                      _updatingOrderIds.contains(order['id'])
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            updateOrderStatus(
                                              order['id'],
                                              value,
                                            );
                                          }
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  // Detail item builder
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrdersRequestFailure implements Exception {
  const _OrdersRequestFailure(this.message);

  final String message;
}
