import 'package:flutter/material.dart';
import '../../DB/Servis/db_helper.dart';

class OrdersPage extends StatefulWidget {
  final String? tableId; // agar stol bo‘yicha filtr qilish kerak bo‘lsa

  const OrdersPage({super.key, this.tableId});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> orders = [];
    if (widget.tableId != null) {
      orders = await DBHelper.getOrdersByTable(widget.tableId!);
    } else {
      orders = await DBHelper.getUnsyncedOrders(); // yoki barcha zakazlarni olish uchun boshqa method
    }

    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Zakazlar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text("Zakazlar yo‘q"))
          : ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (ctx, i) {
          final order = _orders[i];
          final items = (order['items'] as List<Map<String, dynamic>>?) ?? [];

          return Card(
            margin: const EdgeInsets.all(8),
            color: order['status'] == 'pending'
                ? Colors.green.shade50
                : Colors.grey.shade200,
            child: ExpansionTile(
              title: Text(
                "Zakaz #${order['formatted_order_number'] ?? order['id']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Stol: ${order['table_id']} | Jami: ${order['total_price']} so‘m",
              ),
              trailing: Text(
                order['status'] ?? '',
                style: TextStyle(
                  color: order['status'] == 'pending'
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: items.isEmpty
                  ? [const ListTile(title: Text("Mahsulotlar yo‘q"))]
                  : items.map((it) {
                return ListTile(
                  leading: const Icon(Icons.fastfood),
                  title: Text(it['name'] ?? ''),
                  subtitle: Text(
                      "Soni: ${it['quantity']} × ${it['price']}"),
                  trailing: Text(
                    "${(it['quantity'] as num?) ?? 0 * ((it['price'] as num?) ?? 0)} so‘m",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
