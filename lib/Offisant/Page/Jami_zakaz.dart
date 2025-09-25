import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:sora/data/user_datas.dart';
import 'package:win32/win32.dart';

class OrderResponse {
  final bool success;
  final List<Order> orders;
  final int totalCount;
  final int totalAmount;
  final PaymentStats paymentStats;
  final String timestamp;

  OrderResponse({
    required this.success,
    required this.orders,
    required this.totalCount,
    required this.totalAmount,
    required this.paymentStats,
    required this.timestamp,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json['success'] ?? false,
      orders: (json['orders'] as List<dynamic>?)
          ?.map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,  // ✅
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0, // ✅
      paymentStats: PaymentStats.fromJson(json['payment_stats'] ?? {}),
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final String waiterName;
  final int itemsCount;
  final int subtotal;
  final int serviceAmount;
  final int taxAmount;
  final int finalTotal;
  final String completedAt;
  final String paidAt;
  final String status;
  final bool receiptPrinted;
  final String paymentMethod;
  final String paidBy;
  final String completedBy;
  final List<OrderItem> items;
  final String orderDate;

  Order({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.waiterName,
    required this.itemsCount,
    required this.subtotal,
    required this.serviceAmount,
    required this.taxAmount,
    required this.finalTotal,
    required this.completedAt,
    required this.paidAt,
    required this.status,
    required this.receiptPrinted,
    required this.paymentMethod,
    required this.paidBy,
    required this.completedBy,
    required this.items,
    required this.orderDate,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      tableNumber: json['tableNumber'] ?? '',
      waiterName: json['waiterName'] ?? '',
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,    // ✅
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,        // ✅
      serviceAmount: (json['serviceAmount'] as num?)?.toInt() ?? 0, // ✅
      taxAmount: (json['taxAmount'] as num?)?.toInt() ?? 0,      // ✅
      finalTotal: (json['finalTotal'] as num?)?.toInt() ?? 0,    // ✅
      completedAt: json['completedAt'] ?? '',
      paidAt: json['paidAt'] ?? '',
      status: json['status'] ?? '',
      receiptPrinted: json['receiptPrinted'] ?? false,
      paymentMethod: json['paymentMethod'] ?? '',
      paidBy: json['paidBy'] ?? '',
      completedBy: json['completedBy'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      orderDate: json['order_date'] ?? '',
    );
  }
}

class OrderItem {
  final String foodId;
  final String name;
  final int price;
  final int quantity;
  final String categoryName;
  final String? printerId;

  OrderItem({
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.categoryName,
    this.printerId,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      foodId: json['food_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,     // ✅
      quantity: (json['quantity'] as num?)?.toInt() ?? 0, // ✅
      categoryName: json['category_name'] ?? '',
      printerId: json['printer_id'],
    );
  }
}

class PaymentStats {
  final Map<String, int> byMethod;
  final int totalCash;
  final int totalCard;
  final int totalClick;
  final int totalMixed;

  PaymentStats({
    required this.byMethod,
    required this.totalCash,
    required this.totalCard,
    required this.totalClick,
    required this.totalMixed,
  });

  factory PaymentStats.fromJson(Map<String, dynamic> json) {
    return PaymentStats(
      byMethod: (json['by_method'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, (value as num).toInt())) ?? {}, // ✅
      totalCash: (json['total_cash'] as num?)?.toInt() ?? 0,   // ✅
      totalCard: (json['total_card'] as num?)?.toInt() ?? 0,   // ✅
      totalClick: (json['total_click'] as num?)?.toInt() ?? 0, // ✅
      totalMixed: (json['total_mixed'] as num?)?.toInt() ?? 0, // ✅
    );
  }
}

class OrderTablePage1 extends StatefulWidget {
  final String waiterName;

  const OrderTablePage1({required this.waiterName});

  @override
  _OrderTablePageState createState() => _OrderTablePageState();
}

class _OrderTablePageState extends State<OrderTablePage1> {
  OrderResponse? orderResponse;
  String responseText = "Ma'lumot yuklanmadi";
  List<Order> filteredOrders = [];
  bool isLoading = false;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _checkAndLoadDailyData();
  }

  void _checkAndLoadDailyData() {
    setState(() {
      filteredOrders = [];
      responseText =
          "${DateFormat('dd.MM.yyyy').format(selectedDate ?? DateTime.now())} uchun ma'lumotlar yuklanmoqda...";
    });
    fetchZakaz();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0d5720),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        responseText =
            "${DateFormat('dd.MM.yyyy').format(picked)} uchun ma'lumotlar yuklanmoqda...";
      });
      fetchZakaz(forceRefresh: true);
    }
  }

  Future<void> fetchZakaz({bool forceRefresh = false}) async {
    setState(() => isLoading = true);
    final api = await UserDatas().getApi();
    final token = await UserDatas().getToken();
    try {
      var url = Uri.parse("$api/orders/completed");
      print(token);
      var res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          orderResponse = OrderResponse.fromJson(data);
          _filterOrdersByDate();
          responseText =
              filteredOrders.isEmpty
                  ? "${DateFormat('dd.MM.yyyy').format(selectedDate ?? DateTime.now())} da sizning buyurtmalaringiz yo'q"
                  : "Ma'lumotlar muvaffaqiyatli yuklandi";
        });
      } else {
        setState(() {
          responseText = "Xato: ${res.statusCode}\n${res.body}";
        });
      }
    } catch (e) {
      if (mounted) {}
      setState(() {
        responseText = "Xatolik: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterOrdersByDate() {
    if (orderResponse == null) return;

    filteredOrders =
        orderResponse!.orders.where((order) {
          bool waiterMatch =
              order.waiterName.toLowerCase() == widget.waiterName.toLowerCase();
          bool dateMatch = false;

          DateTime? paidDate = DateTime.tryParse(order.paidAt);
          if (paidDate != null && selectedDate != null) {
            dateMatch =
                paidDate.year == selectedDate!.year &&
                paidDate.month == selectedDate!.month &&
                paidDate.day == selectedDate!.day;
          }

          return waiterMatch && dateMatch;
        }).toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalService = filteredOrders.fold(
      0,
      (sum, order) => sum + order.serviceAmount,
    );
    final displayDate = DateFormat(
      'dd.MM.yyyy',
    ).format(selectedDate ?? DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF0d5720),
        title: Column(
          children: [
            Text(
              "Ofitsiant: ${widget.waiterName}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "$displayDate xizmat haqi: ${_formatNumber(totalService)} so'm",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              onPressed: () => _selectDate(context),
              icon: Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'Sana tanlash',
              splashRadius: 24,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              onPressed: () => fetchZakaz(forceRefresh: true),
              icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
              tooltip: 'Yangilash',
              splashRadius: 24,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0d5720), Color(0xFF1a7a32)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0d5720).withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.today_rounded, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "Sana: $displayDate",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child:
                  isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0d5720)),
                            SizedBox(height: 16),
                            Text(
                              responseText,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : filteredOrders.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              responseText,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                      : _buildDataTable(),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 8,
              headingRowHeight: 50,
              dataRowHeight: 55,
              headingRowColor: MaterialStateColor.resolveWith(
                (states) => Color(0xFF0d5720).withOpacity(0.1),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              columns: const [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Buyurtma",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Stol",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Soni",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Narx",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Xizmat",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Jami",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      "Vaqt",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0d5720),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              rows:
                  filteredOrders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final order = entry.value;
                    final isEven = index % 2 == 0;

                    return DataRow(
                      color: MaterialStateColor.resolveWith(
                        (states) =>
                            isEven
                                ? Colors.grey.withOpacity(0.05)
                                : Colors.white,
                      ),
                      cells: [
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              order.orderNumber,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0d5720),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF0d5720).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.tableNumber,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0d5720),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "${order.itemsCount}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "${_formatNumber(order.subtotal)}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "${_formatNumber(order.serviceAmount)}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "${_formatNumber(order.finalTotal)}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0d5720),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    order.completedAt.isNotEmpty
                                        ? "${DateFormat('HH:mm').format(
                                      DateTime.parse(order.completedAt).add(Duration(hours: 5)),
                                    )}  "
                                        "${DateFormat('dd.MM').format(
                                      DateTime.parse(order.completedAt).add(Duration(hours: 5)),
                                    )}"
                                        : "-",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            )

                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(dynamic number) {
    final numStr = number.toString().split('.');
    return numStr[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
