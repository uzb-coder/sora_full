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
  final String createdAt;
  final List<Map<String, dynamic>> items;
  final MixedPaymentDetails? mixedPaymentDetails;

  // 🔹 yangi maydon
  final int percentage;

  PendingOrder({
    required this.id,
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
    // 🔹 konstruktor ga qo‘shildi
    required this.percentage,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    final subtotal = (json['subtotal'] ?? 0).toDouble();
    final finalTotal = (json['final_total'] ?? json['finalTotal'] ?? 0).toDouble();
    final waiterPercentage = json['waiter']?['percentage'] != null
        ? (json['waiter']['percentage'] as num).toInt()
        : 0;

    // 🔹 serviceAmount ni olish + fallback
    double serviceAmount;
    if (json['service_amount'] != null) {
      serviceAmount = (json['service_amount']).toDouble();
    } else if (waiterPercentage > 0 && subtotal > 0) {
      serviceAmount = subtotal * waiterPercentage / 100;
    } else if (finalTotal > subtotal) {
      serviceAmount = finalTotal - subtotal;
    } else {
      serviceAmount = 0;
    }

    return PendingOrder(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ??
          json['formatted_order_number']?.toString() ??
          '',
      formattedOrderNumber: json['formatted_order_number']?.toString() ??
          json['orderNumber']?.toString(),
      tableName: json['table_number']?.toString() ??
          json['tableNumber']?.toString() ??
          json['table_id']?['name']?.toString() ??
          'N/A',
      waiterName: json['waiter_name']?.toString() ??
          json['waiterName']?.toString() ??
          json['user_id']?['first_name']?.toString() ??
          'N/A',
      totalPrice: (json['total_price'] ??
          json['finalTotal'] ??
          json['final_total'] ??
          0)
          .toDouble(),
      serviceAmount: serviceAmount, // ✅ fallback ishlaydi
      finalTotal: finalTotal,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString() ??
          json['completedAt']?.toString() ??
          DateTime.now().toIso8601String(),
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => {
        'name': item['name']?.toString() ?? 'N/A',
        'quantity': item['quantity'] ?? 0,
        'price': item['price'] ?? 0,
        'printer_ip': item['printer_ip']?.toString(),
        'food_id': item['food_id']?.toString() ?? '',
      })
          .toList() ??
          [],
      mixedPaymentDetails: json['mixedPaymentDetails'] != null
          ? MixedPaymentDetails.fromJson(
        json['mixedPaymentDetails'] as Map<String, dynamic>,
      )
          : null,
      percentage: waiterPercentage,
    );
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
