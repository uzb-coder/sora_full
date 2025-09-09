import 'dart:convert';

class PendingOrder {
  final String id;
  final String orderNumber;
  final String? formattedOrderNumber;
  final String? tableName;
  final String? waiterName;
  final double totalPrice;
  final double serviceAmount;
  final double finalTotal;
  final String status;
  final String name;
  final String createdAt;
  final List<Map<String, dynamic>> items;
  final MixedPaymentDetails? mixedPaymentDetails;

  // yangi maydonlar
  final int percentage;
  final String? hallName;

  PendingOrder({
    required this.id,
    required this.name,
    required this.orderNumber,
    this.formattedOrderNumber,
    this.tableName,
    this.waiterName,
    required this.totalPrice,
    required this.serviceAmount,
    required this.finalTotal,
    required this.status,
    required this.createdAt,
    required this.items,
    this.mixedPaymentDetails,
    required this.percentage,
    this.hallName,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    // --- ID & Order number ---
    final dynamic rawId = json['_id'] ?? json['id'] ?? json['order_id'] ?? json['orderId'];
    final String id = (rawId ?? '').toString();

    final String? formattedNum =
        json['formatted_order_number']?.toString() ?? json['orderNumber']?.toString();
    final String orderNumber = formattedNum ??
        json['order_number']?.toString() ??
        id; // fallback id ga

    // --- Table info (map/string/turli kalitlar) ---
    String? tableName;
    String? hallName;
    String name = 'N/A';

    final dynamic table = json['table'] ?? json['table_id'];
    if (table is Map) {
      tableName = (table['display_name'] ?? table['name'] ?? table['number'])?.toString();
      hallName = (table['hall'] is Map) ? table['hall']['name']?.toString() : null;
      name = (table['name'] ?? table['display_name'] ?? 'N/A').toString();
    } else if (table is String) {
      tableName = table;
      name = table;
    } else {
      tableName = json['tableName']?.toString() ?? json['table_number']?.toString() ?? 'N/A';
      name = tableName ?? 'N/A';
    }

    // --- Waiter info & percentage ---
    String? waiterName;
    int percentage = 0;

    final dynamic waiter = json['waiter'] ?? json['user_id'];
    if (waiter is Map) {
      waiterName = (waiter['name'] ??
          waiter['full_name'] ??
          waiter['first_name'] ??
          waiter['username'])
          ?.toString();
      final dynamic wPercent = waiter['percentage'];
      if (wPercent != null) percentage = _asInt(wPercent);
    }

    // fallback kalitlar
    waiterName ??= json['waiterName']?.toString() ?? json['waiter_name']?.toString() ?? 'N/A';
    if (percentage == 0 && json['percentage'] != null) {
      percentage = _asInt(json['percentage']);
    }

    // --- Items (String JSON / List / Map) ---
    final List<Map<String, dynamic>> items =
    _parseItems(json['items'] ?? json['order_items']);

    // --- Subtotal (agar kelmasa itemsdan hisoblaymiz) ---
    double subtotal = _asDouble(json['subtotal']);
    if (subtotal == 0 && items.isNotEmpty) {
      subtotal = _sumItemsSubtotal(items);
    }

    // --- finalTotal / totalPrice / serviceAmount ---
    final double finalTotal =
    _asDouble(json['final_total'] ?? json['finalTotal'] ?? json['total_price']);
    double totalPrice = _asDouble(json['total_price'] ?? json['finalTotal'] ?? json['final_total']);

    double serviceAmount;
    if (json['service_amount'] != null) {
      serviceAmount = _asDouble(json['service_amount']);
    } else if (percentage > 0 && subtotal > 0) {
      serviceAmount = (subtotal * percentage / 100.0);
    } else if (finalTotal > 0 && subtotal > 0 && finalTotal > subtotal) {
      serviceAmount = finalTotal - subtotal;
    } else {
      serviceAmount = 0;
    }

    // Agar totalPrice bo‘sh bo‘lsa, finalTotal yoki subtotal + service bilan to‘ldiramiz
    if (totalPrice == 0) {
      totalPrice = (finalTotal > 0) ? finalTotal : (subtotal + serviceAmount);
    }

    // --- createdAt & status ---
    final String createdAt = (json['createdAt'] ??
        json['created_at'] ??
        json['completedAt'] ??
        DateTime.now().toIso8601String())
        .toString();

    final String status = (json['status'] ?? 'pending').toString();

    // --- Mixed payment ---
    final MixedPaymentDetails? mixedPaymentDetails = (json['mixedPaymentDetails'] is Map)
        ? MixedPaymentDetails.fromJson(json['mixedPaymentDetails'] as Map<String, dynamic>)
        : null;

    return PendingOrder(
      id: id,
      name: name,
      orderNumber: orderNumber,
      formattedOrderNumber: formattedNum,
      tableName: tableName,
      waiterName: waiterName,
      totalPrice: totalPrice,
      serviceAmount: serviceAmount,
      finalTotal: (finalTotal > 0 ? finalTotal : totalPrice),
      status: status,
      createdAt: createdAt,
      items: items,
      mixedPaymentDetails: mixedPaymentDetails,
      percentage: percentage,
      hallName: hallName,
    );
  }
}

// ----------------- Helperlar -----------------

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return fallback;
  return double.tryParse(s) ?? fallback;
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _sumItemsSubtotal(List<Map<String, dynamic>> items) {
  double sum = 0;
  for (final it in items) {
    final q = _asDouble(it['quantity']);
    final p = _asDouble(it['price']);
    sum += (q * p);
  }
  return sum;
}

/// items ni xavfsiz parse qiladi:
/// - String bo‘lsa jsonDecode qiladi
/// - List bo‘lsa Map<String,dynamic> ga o‘tkazadi
/// - Har bir element uchun name/quantity/price/printer_ip/food_id ni normallashtiradi
List<Map<String, dynamic>> _parseItems(dynamic raw) {
  List<dynamic> list;
  if (raw == null) return <Map<String, dynamic>>[];

  try {
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        list = [decoded];
      } else {
        return <Map<String, dynamic>>[];
      }
    } else if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = [raw];
    } else {
      return <Map<String, dynamic>>[];
    }

    return list.map<Map<String, dynamic>>((e) {
      if (e is! Map) return <String, dynamic>{};

      final m = Map<String, dynamic>.from(e);

      // Normalizatsiya
      final name = (m['name'] ??
          m['food_name'] ??
          m['title'] ??
          m['display_name'] ??
          'N/A')
          .toString();

      final quantity = _asDouble(m['quantity'] ?? m['qty'] ?? 0);
      final price = _asDouble(m['price'] ?? m['unit_price'] ?? m['amount'] ?? 0);

      final printerIp = m['printer_ip']?.toString();
      final foodId = (m['food_id'] ?? m['_id'] ?? m['id'])?.toString() ?? '';

      return <String, dynamic>{
        'name': name,
        'quantity': quantity, // UI’da num sifatida ishlating
        'price': price,
        'printer_ip': printerIp,
        'food_id': foodId,
      };
    }).toList();
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

class MixedPaymentDetails {
  final Breakdown breakdown;
  final double cashAmount;
  final double cardAmount;
  final double totalAmount;
  final double changeAmount;
  final DateTime timestamp;

  MixedPaymentDetails({
    required this.breakdown,
    required this.cashAmount,
    required this.cardAmount,
    required this.totalAmount,
    required this.changeAmount,
    required this.timestamp,
  });

  factory MixedPaymentDetails.fromJson(Map<String, dynamic> json) =>
      MixedPaymentDetails(
        breakdown: Breakdown.fromJson(
          json['breakdown'] as Map<String, dynamic>? ?? {},
        ),
        cashAmount: (json['cashAmount'] ?? 0).toDouble(),
        cardAmount: (json['cardAmount'] ?? 0).toDouble(),
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
        changeAmount: (json['changeAmount'] ?? 0).toDouble(),
        timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class Breakdown {
  final String cashPercentage;
  final String cardPercentage;

  Breakdown({required this.cashPercentage, required this.cardPercentage});

  factory Breakdown.fromJson(Map<String, dynamic> json) => Breakdown(
    cashPercentage: json['cash_percentage']?.toString() ?? '0.0',
    cardPercentage: json['card_percentage']?.toString() ?? '0.0',
  );
}

// Cache uchun data wrapper
class CachedData {
  final List<PendingOrder> data;
  final DateTime timestamp;

  CachedData(this.data, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > 30;
}
