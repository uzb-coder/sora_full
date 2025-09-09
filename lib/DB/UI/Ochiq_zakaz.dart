import 'package:flutter/material.dart';

import '../Servis/db_helper.dart';

class ClosedOrdersPage extends StatefulWidget {
  const ClosedOrdersPage({super.key});

  @override
  State<ClosedOrdersPage> createState() => _ClosedOrdersPageState();
}

class _ClosedOrdersPageState extends State<ClosedOrdersPage> {
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadClosedOrders();
  }

  Future<void> _loadClosedOrders() async {
    final orders = await DBHelper.getOpenOrders();
    setState(() {
      _orders = orders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Yopilgan zakazlar (${_orders.length} ta)"),
      ),
      body: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final items = order['items'] as List<Map<String, dynamic>>;

          return Card(
            margin: const EdgeInsets.all(8),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zakaz ma’lumotlari
                  Text(
                    "Zakaz ID: ${order['id']} | Stol: ${order['table_id']} | Jami: ${order['total_price']} so‘m",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Mahsulotlar jadvali
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      border: TableBorder.all(color: Colors.grey),
                      columns: const [
                        DataColumn(label: Text("Mahsulot")),
                        DataColumn(label: Text("Soni")),
                        DataColumn(label: Text("Narxi")),
                        DataColumn(label: Text("Umumiy")),
                      ],
                      rows: items.map((item) {
                        final quantity = item['quantity'] ?? 0;
                        final price = item['price'] ?? 0.0;
                        final total = quantity * price;
                        return DataRow(
                          cells: [
                            DataCell(Text(item['name'].toString())),
                            DataCell(Text(quantity.toString())),
                            DataCell(Text("$price so‘m")),
                            DataCell(Text("$total so‘m")),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
