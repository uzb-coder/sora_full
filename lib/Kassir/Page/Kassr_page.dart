import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sora/Global/Api_global.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../Offisant/Page/Users_page.dart';
import '../Model/KassirModel.dart';

class FastUnifiedPendingPaymentsPage1 extends StatefulWidget {
  final token;
  const FastUnifiedPendingPaymentsPage1({super.key, required this.token});

  @override
  State<FastUnifiedPendingPaymentsPage1> createState() =>
      _FastUnifiedPendingPaymentsPageState();
}

class _FastUnifiedPendingPaymentsPageState
    extends State<FastUnifiedPendingPaymentsPage1> {
  String selectedDateRange = 'open';
  String searchText = '';
  PendingOrder? selectedOrder;
  bool isPaymentModalVisible = false;
  bool isLoading = false;
  String? errorMessage;
  List<PendingOrder> openOrders = [];
  List<PendingOrder> closedOrders = [];
  Timer? _refreshTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Polling interval 5 soniya - real-time ga yaqinlashtirildi
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_disposed) _refreshData();
    });
  }

  static const String baseUrl = '${ApiConfig.baseUrl}';
  static String? _token;
  static final Map<String, CachedData> _cache = {};
  static DateTime _lastFetch = DateTime(2000);

  static Future<String?> _getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  // Parallel API calls - 2 ta API ni bir vaqtda chaqirish
  Future<Map<String, List<PendingOrder>>> fetchAllOrdersFast() async {
    final now = DateTime.now();

    // Cache check - 30 soniya ichida qayta chaqirmaydi
    if (_cache.containsKey('pending') &&
        _cache.containsKey('closed') &&
        !_cache['pending']!.isExpired &&
        !_cache['closed']!.isExpired) {
      return {
        'pending': _cache['pending']!.data,
        'closed': _cache['closed']!.data,
      };
    }

    try {
      // Widget orqali uzatilgan token ishlatish
      final kassirToken = widget.token;

      // PARALLEL API CALLS - 2 ta API ni bir vaqtda
      final results = await Future.wait([
        http.get(
          Uri.parse('$baseUrl/orders/my-pending'),
          headers: {
            'Authorization': 'Bearer $kassirToken',
            'Content-Type': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$baseUrl/orders/pending-payments'),
          headers: {
            'Authorization': 'Bearer $kassirToken',
            'Content-Type': 'application/json',
          },
        ),
      ], eagerError: false);

      List<PendingOrder> pendingOrders = [];
      List<PendingOrder> closedOrders = [];

      // Pending orders parse
      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        final orders =
        (data is Map && data['orders'] is List
            ? data['orders'] as List
            : data is List
            ? data
            : []);
        pendingOrders =
            orders
                .map(
                  (orderJson) =>
                  PendingOrder.fromJson(orderJson as Map<String, dynamic>),
            )
                .toList();
      }
      // Closed orders parse
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        final orders =
        (data is Map && data['pending_orders'] is List
            ? data['pending_orders'] as List
            : data is List
            ? data
            : []);
        closedOrders =
            orders
                .map(
                  (orderJson) =>
                  PendingOrder.fromJson(orderJson as Map<String, dynamic>),
            )
                .toList();
      }

      // Cache update
      _cache['pending'] = CachedData(pendingOrders, now);
      _cache['closed'] = CachedData(closedOrders, now);
      _lastFetch = now;

      return {'pending': pendingOrders, 'closed': closedOrders};
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      // Eski cache qaytarish agar xatolik bo'lsa
      return {
        'pending': _cache['pending']?.data ?? [],
        'closed': _cache['closed']?.data ?? [],
      };
    }
  }

  Future<bool> closeOrderFast(
      String orderId,
      List<Map<String, dynamic>> items,
      ) async {
    try {
      final response = await http
          .put(
        Uri.parse('$baseUrl/orders/close/$orderId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Printer calls - parallel
        final uniquePrinterIPs =
        items
            .map((item) => item['printer_ip'] as String?)
            .where((ip) => ip != null && ip.isNotEmpty)
            .toSet();

        if (uniquePrinterIPs.isNotEmpty) {
          // Printer calls parallel - kutmaydi
          unawaited(
            Future.wait(
              uniquePrinterIPs.map((ip) => _sendToPrinter(ip!, orderId)),
              eagerError: false,
            ),
          );
        }

        // Cache clear
        _cache.clear();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error closing order: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> processPaymentFast(
      String orderId,
      Map<String, dynamic> paymentData,
      ) async {
    // _getToken() o'rniga widget.token ishlatamiz
    if (widget.token == null) {
      return {'success': false, 'message': 'Token topilmadi'};
    }

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/kassir/payment/$orderId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(paymentData),
      )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _cache.clear(); // Keshni tozalash
        return {
          'success': true,
          'message':
          data['message']?.toString() ?? 'To‘lov muvaffaqiyatli amalga oshirildi',
          'data': data,
        };
      }

      return {
        'success': false,
        'message': data['message']?.toString() ?? 'To‘lovni amalga oshirishda xato',
      };
    } catch (e) {
      debugPrint('To‘lovni amalga oshirishda xato: $e');
      return {'success': false, 'message': 'To‘lovni amalga oshirishda xato: $e'};
    }
  }

  Future<Map<String, dynamic>> cancelOrderItemFast({
    required String orderId,
    required String foodId,
    required int cancelQuantity,
    required String reason,
    required String notes,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/orders/$orderId/cancel-item'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'food_id': foodId,
          'cancel_quantity': cancelQuantity,
          'reason': reason,
          'notes': notes,
        }),
      )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Clear cache to ensure fresh data on next fetch
        _cache.clear();
        return {
          'success': true,
          'message':
          data['message']?.toString() ?? 'Item cancelled successfully',
        };
      }

      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Failed to cancel item',
      };
    } catch (e) {
      debugPrint('Error cancelling item: $e');
      return {'success': false, 'message': 'Error cancelling item: $e'};
    }
  }

  static Future<void> _sendToPrinter(String printerIP, String orderId) async {
    try {
      await http
          .post(
        Uri.parse('http://$printerIP:9100/'),
        headers: {'Content-Type': 'text/plain'},
        body: 'Order #$orderId Closed\n',
      )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Printer error $printerIP: $e');
    }
  }

  static void clearCache() => _cache.clear();

  Future<void> _loadData() async {
    if (_disposed) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await fetchAllOrdersFast();

      if (!_disposed) {
        setState(() {
          openOrders = result['pending'] ?? [];
          closedOrders = result['closed'] ?? [];
          isLoading = false;

          if (openOrders.isEmpty && closedOrders.isEmpty) {
            errorMessage = 'No orders found';
          }
        });
      }
    } catch (e) {
      if (!_disposed) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load orders: $e';
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_disposed || isLoading) return;

    try {
      final result = await fetchAllOrdersFast();

      if (!_disposed) {
        setState(() {
          openOrders = result['pending'] ?? [];
          closedOrders = result['closed'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _handleDateRangeChange(String key) {
    if (_disposed) return;
    setState(() {
      selectedDateRange = key;
      selectedOrder = null;
      searchText = '';
    });
  }

  void _handleSearch(String value) {
    if (_disposed) return;
    setState(() => searchText = value);
  }

  void _handlePrintReceipt() {
    if (selectedOrder == null) {
      _showSnackBar('Avval zakazni tanlang!');
      return;
    }
    debugPrint(
      'Printing receipt for order ${selectedOrder!.formattedOrderNumber}',
    );
  }

  Future<void> _handleCloseOrder() async {
    if (selectedOrder == null) {
      _showSnackBar('Avval zakazni tanlang!');
      return;
    }

    setState(() => isLoading = true);

    final success = await closeOrderFast(
      selectedOrder!.id,
      selectedOrder!.items,
    );

    if (!_disposed) {
      setState(() {
        isLoading = false;
        if (success) {
          openOrders.removeWhere((order) => order.id == selectedOrder!.id);
          selectedOrder = null;
        } else {
          _showSnackBar('Failed to close order');
        }
      });
      // Background refresh
      unawaited(_refreshData());
    }
  }

  void _handleOpenPaymentModal() {
    if (selectedOrder == null) {
      _showSnackBar('Avval zakazni tanlang!');
      return;
    }
    setState(() => isPaymentModalVisible = true);
  }

  Future<Map<String, dynamic>> _processPaymentHandler(
      Map<String, dynamic> apiPayload,
      ) async {
    setState(() => isLoading = true);
    final result = await processPaymentFast(
      selectedOrder!.id,
      apiPayload['paymentData'] as Map<String, dynamic>,
    );
    if (!_disposed) setState(() => isLoading = false);
    return result;
  }

  void _handlePaymentSuccess(Map<String, dynamic> result) {
    if (_disposed || selectedOrder == null) return;

    setState(() {
      closedOrders.removeWhere((order) => order.id == selectedOrder!.id);
      selectedOrder = null;
      isPaymentModalVisible = false;
    });

    // Mini snackbar markazda chiqishi
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Center(
          // SnackBarni ekranda markazga joylashtirish uchun
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
              MediaQuery.of(context).size.width *
                  0.8, // ekran kengligining 80% gacha
              minWidth: 100, // minimal kenglik (ixtiyoriy)
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: const Text(
              "✅ Тўлов муваффақиятли қабул қилинди!",
              style: TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      animationDuration: const Duration(milliseconds: 50),
      reverseAnimationDuration: const Duration(milliseconds: 50),
    );

    unawaited(_refreshData());
  }

  List<PendingOrder> _getCurrentData() {
    final currentData = selectedDateRange == 'open' ? openOrders : closedOrders;
    if (searchText.isEmpty) return currentData;

    final searchLower = searchText.toLowerCase();
    return currentData.where((order) {
      return order.orderNumber.toLowerCase().contains(searchLower) ||
          order.formattedOrderNumber?.toLowerCase().contains(searchLower) ==
              true ||
          order.tableName?.toLowerCase().contains(searchLower) == true ||
          order.waiterName?.toLowerCase().contains(searchLower) == true;
    }).toList();
  }

  void _showSnackBar(String message) {
    if (_disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> showCancelDialog(
      String orderId,
      String foodId,
      int itemIndex,
      ) async {
    if (_disposed) return;

    String reason = "Mijoz bekor qildi"; // Default sabab
    String notes = "ixtiyor"; // Modalda ko‘rinmaydi, lekin API'ga ketadi
    int cancelQuantity = 1; // Default miqdor

    // Tanlangan taom ma'lumotlarini olish
    final item = selectedOrder!.items[itemIndex];
    final String foodName = item['name']?.toString() ?? 'N/A';
    final int availableQuantity = item['quantity'] ?? 0;
    final double foodPrice = item['price']?.toDouble() ?? 0.0;

    List<String> reasons = [
      "Mijoz bekor qildi",
      "Klient shikoyat qildi",
      "Noto‘g‘ri tayyorlangan",
      "Mahsulot tugagan",
      "Xizmat sifati past",
      "Boshqa",
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            "Mahsulotni bekor qilish",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Taom ma'lumotlari
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Taom: $foodName",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Umumiy soni: $availableQuantity dona",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.lightBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Narxi: ${NumberFormat().format(foodPrice)} so'm",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sabab combobox
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: InputDecoration(
                    labelText: "Sabab",
                    labelStyle: const TextStyle(color: Color(0xFF666666)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF28a745)),
                    ),
                  ),
                  items:
                  reasons.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        style: const TextStyle(color: Color(0xFF333333)),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) reason = val;
                  },
                ),
                const SizedBox(height: 16),

                // Miqdor input
                TextFormField(
                  initialValue: cancelQuantity.toString(),
                  decoration: InputDecoration(
                    labelText: "Bekor qilinadigan miqdor",
                    labelStyle: const TextStyle(color: Color(0xFF666666)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF28a745)),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    final inputQuantity = int.tryParse(val ?? '') ?? 0;
                    if (inputQuantity <= 0) {
                      return "Miqdor 0 dan katta bo‘lishi kerak";
                    }
                    if (inputQuantity > availableQuantity) {
                      return "Kiritilgan miqdor mavjud miqdordan ($availableQuantity) oshib ketdi";
                    }
                    return null;
                  },
                  onChanged: (val) {
                    cancelQuantity = int.tryParse(val) ?? 1;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Bekor qilish",
                style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28a745),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (cancelQuantity <= 0 || cancelQuantity > availableQuantity) {
                  _showSnackBar("Noto‘g‘ri miqdor kiritildi!");
                  return;
                }
                Navigator.pop(context);
                await _deleteItem(
                  orderId,
                  foodId,
                  itemIndex,
                  reason,
                  notes,
                  cancelQuantity,
                );
              },
              child: const Text(
                "Tasdiqlash",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteItem(
      String orderId,
      String foodId,
      int itemIndex,
      String reason,
      String notes,
      int cancelQuantity,
      ) async {
    setState(() => isLoading = true);

    final result = await cancelOrderItemFast(
      orderId: orderId,
      foodId: foodId,
      cancelQuantity: cancelQuantity,
      reason: reason,
      notes: notes,
    );

    if (!_disposed) {
      setState(() {
        isLoading = false;
        if (result['success'] == true) {
          if (selectedOrder != null && selectedOrder!.id == orderId) {
            // Mahsulot sonini kamaytirish
            final item = selectedOrder!.items[itemIndex];
            final currentQuantity = item['quantity'] as int;
            final newQuantity = currentQuantity - cancelQuantity;

            if (newQuantity <= 0) {
              // Agar soni 0 ga teng yoki undan kichik bo'lsa, butunlay o'chirish
              selectedOrder!.items.removeAt(itemIndex);
            } else {
              // Aks holda faqat sonini yangilash
              selectedOrder!.items[itemIndex]['quantity'] = newQuantity;
            }

            // Agar buyurtma bo'sh bo'lsa, ro'yxatdan o'chirish
            if (selectedOrder!.items.isEmpty) {
              openOrders.removeWhere((order) => order.id == orderId);
              closedOrders.removeWhere((order) => order.id == orderId);
              selectedOrder = null;
            }
          }
          showTopSnackBar(
            Overlay.of(context),
            Material(
              color: Colors.transparent,
              child: Center(
                // SnackBarni ekranda markazga joylashtirish uchun
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width *
                        0.8, // ekran kengligining 80% gacha
                    minWidth: 100, // minimal kenglik (ixtiyoriy)
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    "✅ Mahsulot bekor qilindi!",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            animationDuration: const Duration(milliseconds: 50),
            reverseAnimationDuration: const Duration(milliseconds: 50),
          );
          unawaited(_refreshData());
        } else {
          _showSnackBar(
            result['message']?.toString() ?? 'Failed to cancel item',
          );
        }
      });
    }
  }

  // YENGIL ORDER CARD - animatsiyasiz
  Widget _buildOrderCard(PendingOrder order) {
    final isSelected = selectedOrder?.id == order.id;
    final rowColor =
    isSelected
        ? const Color(0xFFd4edda)
        : selectedDateRange == 'closed'
        ? const Color(0xFFffe6e6)
        : _getStatusColor(order);

    return InkWell(
      onTap: () => setState(() => selectedOrder = order),
      child: Container(
        decoration: BoxDecoration(
          color: rowColor,
          border:
          isSelected
              ? Border.all(color: const Color(0xFF28a745), width: 2)
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child:
        selectedDateRange == 'open'
            ? _buildOpenOrderRow(order)
            : _buildClosedOrderRow(order),
      ),
    );
  }

  Widget _buildOpenOrderRow(PendingOrder order) {
    final createdAt = DateTime.parse(order.createdAt);
    return Row(
      children: [
        _buildDataCell(DateFormat('dd.MM').format(createdAt), flex: 1),
        _buildDataCell(DateFormat('HH:mm').format(createdAt), flex: 1),
        _buildDataCell(
          order.formattedOrderNumber ?? order.orderNumber,
          flex: 1,
        ),
        _buildDataCell(order.waiterName ?? 'N/A', flex: 2),
        _buildDataCell(order.tableName ?? 'N/A', flex: 1),
        _buildDataCell(NumberFormat().format(order.totalPrice), flex: 2),
      ],
    );
  }

  Widget _buildClosedOrderRow(PendingOrder order) {
    final createdAt = DateTime.parse(order.createdAt);
    return Row(
      children: [
        _buildDataCell(DateFormat('dd.MM.yy').format(createdAt), flex: 1),
        _buildDataCell(DateFormat('HH:mm').format(createdAt), flex: 1),
        _buildDataCell(
          order.formattedOrderNumber ?? order.orderNumber,
          flex: 1,
        ),
        _buildDataCell(order.tableName ?? 'N/A', flex: 1),
        _buildDataCell(order.waiterName ?? 'N/A', flex: 1),
        _buildDataCell(order.items.length.toString(), flex: 1),
        _buildDataCell(
          '${NumberFormat().format(order.totalPrice)} so\'m',
          flex: 2,
        ),
      ],
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    ),
  );

  Widget _buildHeaderCell(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _renderSelectedOrderInfo() {
    if (selectedOrder == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          'Заказ танланг',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    final isClosedOrder = selectedDateRange == 'closed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isClosedOrder ? Colors.black : Colors.green,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isClosedOrder ? "Тўлов кутилмоқда" : "Очиқ заказ"}: ${selectedOrder!.formattedOrderNumber ?? selectedOrder!.orderNumber}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Stol: ${selectedOrder!.tableName}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Афитсант: ${selectedOrder!.waiterName}',
            style: const TextStyle(fontSize: 16),
          ),
          if (selectedOrder!.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Таомлар:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ...selectedOrder!.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final foodId = item['food_id']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item["name"] ?? "N/A"} - ${item["quantity"] ?? 0} dona',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed:
                      foodId.isEmpty
                          ? null
                          : () => showCancelDialog(
                        selectedOrder!.id,
                        foodId,
                        index,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          Text(
            'Жами: ${NumberFormat().format(selectedOrder!.totalPrice)} so\'m',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _getCurrentData();
    final dateRangeButtons = [
      {'key': 'open', 'label': 'Очиқ\nзаказлар ${openOrders.length}'},
      {'key': 'closed', 'label': 'Ёпилган\nзаказлар ${closedOrders.length}'},
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Кассир саҳифа'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              clearCache();
              _loadData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFF999999), width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children:
                        dateRangeButtons
                            .map(
                              (btn) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  selectedDateRange == btn['key']
                                      ? const Color(0xFF28a745)
                                      : const Color(0xFFf5f5f5),
                                  foregroundColor:
                                  selectedDateRange == btn['key']
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      0,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF999999),
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed:
                                    () => _handleDateRangeChange(
                                  btn['key'] as String,
                                ),
                                child: Text(
                                  btn['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Қидирув',
                          suffixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onChanged: _handleSearch,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFdddddd),
                          width: 2,
                        ),
                        color: const Color(0xFFf8f8f8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(
                            selectedDateRange == 'closed'
                                ? "Тўлов\nКутилмоқда"
                                : "Очиқ\nЗаказлар",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Жами'),
                              Text(currentData.length.toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _renderSelectedOrderInfo(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFd4d0c8),
                        border: Border.all(
                          color: const Color(0xFFdddddd),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedDateRange == 'closed'
                            ? "ЁПИЛГАН ЗАКАЗЛАР (ТЎЛОВ КУТИЛМОҚДА)"
                            : "ОЧИҚ ЗАКАЗЛАР",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child:
                      selectedDateRange == 'closed'
                          ? Row(
                        children: [
                          _buildHeaderCell('Сана', flex: 1),
                          _buildHeaderCell('Вақт', flex: 1),
                          _buildHeaderCell('Заказ ', flex: 1),
                          _buildHeaderCell('Стол ', flex: 1),
                          _buildHeaderCell('Официант ', flex: 1),
                          _buildHeaderCell('Таомлар ', flex: 1),
                          _buildHeaderCell('Жами', flex: 2),
                        ],
                      )
                          : Row(
                        children: [
                          _buildHeaderCell('Сана', flex: 1),
                          _buildHeaderCell('Вақт', flex: 1),
                          _buildHeaderCell('Заказ', flex: 1),
                          _buildHeaderCell('Официант', flex: 2),
                          _buildHeaderCell('Стол', flex: 1),
                          _buildHeaderCell('Жами', flex: 2),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child:
                        isLoading
                            ? const Center(
                          child: CircularProgressIndicator(),
                        )
                            : errorMessage != null
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(errorMessage!),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  clearCache();
                                  _loadData();
                                },
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                            : currentData.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedDateRange == 'open'
                                    ? Icons.restaurant_menu
                                    : Icons.payment,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedDateRange == 'open'
                                    ? "Hozircha ochiq zakazlar yo'q"
                                    : "To'lov kutayotgan zakazlar yo'q",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  clearCache();
                                  _loadData();
                                },
                                child: const Text('Yangilash'),
                              ),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: () async {
                            clearCache();
                            await _loadData();
                          },
                          child: ListView.builder(
                            itemCount: currentData.length,
                            itemBuilder:
                                (context, index) =>
                                _buildOrderCard(currentData[index]),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: const Color(0xFFe8e8e8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildActionButton(
                                text: 'Чоп этиш',
                                onPressed: _handlePrintReceipt,
                                isEnabled: selectedOrder != null,
                              ),
                              const SizedBox(width: 8),
                              if (selectedDateRange == 'open')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    selectedOrder != null
                                        ? const Color(0xFF28a745)
                                        : const Color(0xFFf5f5f5),
                                    foregroundColor:
                                    selectedOrder != null
                                        ? Colors.white
                                        : Colors.black,
                                    minimumSize: const Size(120, 70),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: Color(0xFF999999),
                                        width: 2,
                                      ),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  onPressed:
                                  selectedOrder != null
                                      ? _handleCloseOrder
                                      : null,
                                  child: const Text(
                                    "Заказни ёпиш",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else if (selectedDateRange == 'closed' &&
                                  selectedOrder != null)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007bff),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(120, 70),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: Color(0xFF999999),
                                        width: 2,
                                      ),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  onPressed: _handleOpenPaymentModal,
                                  child: const Text(
                                    "Тўловни қабул қилиш",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildActionButton(
                                text: 'Назад',
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                text: 'Выход',
                                onPressed:
                                    () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserListPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPaymentModalVisible && selectedOrder != null)
            FastPaymentModal(
              visible: isPaymentModalVisible,
              onClose: () => setState(() => isPaymentModalVisible = false),
              selectedOrder: selectedOrder!,
              onPaymentSuccess: _handlePaymentSuccess,
              processPayment: _processPaymentHandler,
              isProcessing: isLoading,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFf5f5f5),
      foregroundColor: Colors.black,
      minimumSize: const Size(120, 70),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF999999), width: 2),
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.2),
    ),
    onPressed: isEnabled ? onPressed : null,
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );

  Color _getStatusColor(PendingOrder order) {
    if (selectedDateRange == 'closed') return const Color(0xFFdc3545);
    switch (order.status) {
      case 'pending':
        return const Color(0xFF1890ff);
      case 'preparing':
        return const Color(0xFFfa8c16);
      case 'ready':
        return const Color(0xFF52c41a);
      case 'served':
        return const Color(0xFF722ed1);
      default:
        return const Color(0xFF1890ff);
    }
  }
}

class FastPaymentModal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final PendingOrder selectedOrder;
  final Function(Map<String, dynamic>) onPaymentSuccess;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  processPayment;
  final bool isProcessing;

  const FastPaymentModal({
    super.key,
    required this.visible,
    required this.onClose,
    required this.selectedOrder,
    required this.onPaymentSuccess,
    required this.processPayment,
    required this.isProcessing,
  });

  @override
  State<FastPaymentModal> createState() => _FastPaymentModalState();
}

class _FastPaymentModalState extends State<FastPaymentModal> {
  String _paymentMethod = 'cash';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _paymentAmountController =
  TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    decimalDigits: 0,
    symbol: '',
  );
  double _paymentAmount = 0;
  double _changeAmount = 0;
  double _cashAmount = 0;
  double _cardAmount = 0;

  double get _orderTotal => widget.selectedOrder.totalPrice;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  void _resetForm() {
    final total = _orderTotal;
    setState(() {
      _paymentMethod = 'cash';
      _paymentAmount = total;
      _changeAmount = 0;
      _cashAmount = total;
      _cardAmount = 0;
      _notesController.clear();
      _paymentAmountController.text = _currencyFormat.format(total);
      _cashAmountController.text = _currencyFormat.format(total);
      _cardAmountController.text = _currencyFormat.format(0);
    });
  }

  void _handlePaymentMethodChange(String? method) {
    if (method == null || !mounted) return;
    setState(() {
      _paymentMethod = method;
      final total = _orderTotal;
      if (method == 'cash') {
        _paymentAmount = total;
        _paymentAmountController.text = _currencyFormat.format(total);
        _changeAmount = 0;
        _cashAmount = total;
        _cardAmount = 0;
      } else if (method == 'card' || method == 'click') {
        _paymentAmount = total;
        _paymentAmountController.text = _currencyFormat.format(total);
        _changeAmount = 0;
        _cashAmount = 0;
        _cardAmount = total;
      } else if (method == 'mixed') {
        _cashAmount = total / 2;
        _cardAmount = total / 2;
        _cashAmountController.text = _currencyFormat.format(_cashAmount);
        _cardAmountController.text = _currencyFormat.format(_cardAmount);
        _changeAmount = 0;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    final paymentData = <String, dynamic>{
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text,
    };

    if (_paymentMethod == 'mixed') {
      final totalAmount = _cashAmount + _cardAmount;
      if (_cashAmount <= 0 || _cardAmount <= 0) {
        _showSnackBar(
          "Aralash to'lov uchun naqd va karta summasi 0 dan katta bo'lishi kerak!",
        );
        return;
      }
      if (totalAmount < _orderTotal) {
        _showSnackBar("To'lov summasi yetarli emas!");
        return;
      }
      paymentData['mixedPayment'] = {
        'cashAmount': _cashAmount,
        'cardAmount': _cardAmount,
        'totalAmount': totalAmount,
        'changeAmount': _changeAmount,
      };
      paymentData['paymentAmount'] = totalAmount;
      paymentData['changeAmount'] = _changeAmount;
    } else {
      if (_paymentAmount <= 0) {
        _showSnackBar("To'lov summasi 0 dan katta bo'lishi kerak!");
        return;
      }
      if (_paymentMethod == 'cash' && _paymentAmount < _orderTotal) {
        _showSnackBar("Naqd to'lov summasi yetarli emas!");
        return;
      }
      paymentData['paymentAmount'] = _paymentAmount;
      paymentData['changeAmount'] = _changeAmount;
    }

    final result = await widget.processPayment({'paymentData': paymentData});
    if (!mounted) return;

    if (result['success'] == true) {
      _resetForm();
      widget.onClose();
      widget.onPaymentSuccess(result);
    } else {
      _showSnackBar(
        result['message']?.toString() ?? "To'lov qabul qilishda xatolik!",
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Center(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.9, // 90% balandlik
            minWidth: 280,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - fix qilingan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "💰 TO'LOV QABUL QILISH",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zakaz #${widget.selectedOrder.formattedOrderNumber ?? widget.selectedOrder.orderNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Zakaz summasi
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf8f9fa),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Zakaz summasi:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_currencyFormat.format(_orderTotal)} so\'m',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF28a745),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // To'lov usuli
                        const Text(
                          "To'lov usuli",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: [
                            ChoiceChip(
                              label: const Text('💵 Naqd', style: TextStyle(fontSize: 12)),
                              selected: _paymentMethod == 'cash',
                              onSelected: (selected) => _handlePaymentMethodChange('cash'),
                            ),
                            ChoiceChip(
                              label: const Text('💳 Karta', style: TextStyle(fontSize: 12)),
                              selected: _paymentMethod == 'card',
                              onSelected: (selected) => _handlePaymentMethodChange('card'),
                            ),
                            ChoiceChip(
                              label: const Text('📱 Click', style: TextStyle(fontSize: 12)),
                              selected: _paymentMethod == 'click',
                              onSelected: (selected) => _handlePaymentMethodChange('click'),
                            ),
                            ChoiceChip(
                              label: const Text('🔄 Aralash', style: TextStyle(fontSize: 12)),
                              selected: _paymentMethod == 'mixed',
                              onSelected: (selected) => _handlePaymentMethodChange('mixed'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // To'lov summasi (oddiy usul)
                        if (_paymentMethod != 'mixed')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("To'lov summasi"),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _paymentAmountController,
                                      keyboardType: TextInputType.number,
                                      enabled: !['card', 'click'].contains(_paymentMethod),
                                      decoration: const InputDecoration(
                                        hintText: 'Summa',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      validator: (value) {
                                        final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                        if (amount <= 0) {
                                          return "To'lov summasi 0 dan katta bo'lishi kerak!";
                                        }
                                        if (_paymentMethod == 'cash' && amount < _orderTotal) {
                                          return "Naqd to'lov summasi yetarli emas!";
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
                                        setState(() {
                                          _paymentAmount = amount;
                                          if (_paymentMethod == 'cash') {
                                            _changeAmount = (amount - _orderTotal).clamp(0, double.infinity);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  if (_paymentMethod == 'cash') ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        enabled: false,
                                        initialValue: _currencyFormat.format(_changeAmount),
                                        decoration: const InputDecoration(
                                          labelText: 'Qaytim',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              if (['card', 'click'].contains(_paymentMethod)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFe6f7ff),
                                    border: Border.all(color: const Color(0xFF91d5ff)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _paymentMethod == 'card' ? "💳 Karta to'lov - aniq summa" : "📱 Click to'lov - aniq summa",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF0050b3)),
                                  ),
                                ),
                              ],
                            ],
                          ),

                        // Aralash to'lov
                        if (_paymentMethod == 'mixed') ...[
                          const Text("Aralash to'lov"),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cashAmountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Naqd',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  validator: (value) {
                                    final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                    if (amount <= 0) return "Naqd summa 0'dan katta bo'lishi kerak!";
                                    return null;
                                  },
                                  onChanged: (value) {
                                    final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
                                    setState(() {
                                      _cashAmount = amount;
                                      final total = amount + _cardAmount;
                                      _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _cardAmountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Karta',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  validator: (value) {
                                    final amount = double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0;
                                    if (amount <= 0) return "Karta summa 0'dan katta bo'lishi kerak!";
                                    return null;
                                  },
                                  onChanged: (value) {
                                    final amount = double.tryParse(value.replaceAll(',', '') ?? '') ?? 0;
                                    setState(() {
                                      _cardAmount = amount;
                                      final total = _cashAmount + amount;
                                      _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Izohlar
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Izohlar',
                            hintText: "To'lov haqida qo'shimcha ma'lumot...",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Jami ma'lumot
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf8f9fa),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Jami to\'lov:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    '${_currencyFormat.format(_paymentMethod == 'mixed' ? (_cashAmount + _cardAmount) : _paymentAmount)} so\'m',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Kerakli:', style: TextStyle(fontSize: 14)),
                                  Text('${_currencyFormat.format(_orderTotal)} so\'m', style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              if ((_paymentMethod == 'cash' || _paymentMethod == 'mixed') && _changeAmount > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Qaytim:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('${_currencyFormat.format(_changeAmount)} so\'m', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer - fix qilingan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _resetForm();
                          widget.onClose();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("❌ Bekor qilish", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.isProcessing ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF28a745),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.isProcessing ? "⏳ Ishlanmoqda..." : "✅ Qabul qilish",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
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

  @override
  void dispose() {
    _notesController.dispose();
    _paymentAmountController.dispose();
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }
}
