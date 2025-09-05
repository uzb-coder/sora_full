import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../Servis/db_helper.dart';
import 'Menu.dart';

// ====== MODELAR ======
class HallEntity {
  final String id;
  final String name;

  HallEntity({required this.id, required this.name});

  factory HallEntity.fromMap(Map<String, Object?> m) {
    return HallEntity(
      id: (m['id'] ?? '') as String,
      name: (m['name'] ?? '') as String,
    );
  }
}

class TableEntity {
  final String id;
  final String hallId;
  final String name;
  final String status;
  final int guestCount;
  final int capacity;
  final String? displayName;

  TableEntity({
    required this.id,
    required this.hallId,
    required this.name,
    required this.status,
    required this.guestCount,
    required this.capacity,
    this.displayName,
  });

  factory TableEntity.fromMap(Map<String, Object?> m) {
    return TableEntity(
      id: (m['id'] ?? '') as String,
      hallId: (m['hall_id'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      status: (m['status'] ?? 'open') as String,
      guestCount: (m['guest_count'] ?? 0) as int,
      capacity: (m['capacity'] ?? 0) as int,
      displayName: m['display_name'] as String?,
    );
  }

  String get title => (displayName?.trim().isNotEmpty == true)
      ? displayName!.trim()
      : (name.isNotEmpty ? name : id);
}

// ====== REPO ======
class HallTableRepo {
  final Future<Database> _db = DBHelper.database;

  Future<List<HallEntity>> getHalls() async {
    final db = await _db;
    final rows = await db.query('halls', orderBy: 'name ASC');
    return rows.map((e) => HallEntity.fromMap(e)).toList();
  }

  Future<List<TableEntity>> getTablesByHall(String hallId) async {
    final db = await _db;
    final rows = await db.query(
      'tables',
      where: 'hall_id = ?',
      whereArgs: [hallId],
      orderBy: 'number ASC, name ASC',
    );
    return rows.map((e) => TableEntity.fromMap(e)).toList();
  }
}

// ====== UI ======
class HallTablesPage extends StatefulWidget {
  const HallTablesPage({super.key});

  @override
  State<HallTablesPage> createState() => _HallTablesPageState();
}

class _HallTablesPageState extends State<HallTablesPage> {
  final repo = HallTableRepo();

  List<HallEntity> _halls = [];
  String? _selectedHallId;
  List<TableEntity> _tables = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final halls = await repo.getHalls();
      String? sel = _selectedHallId;
      if (halls.isNotEmpty) {
        sel ??= halls.first.id;
      }
      List<TableEntity> tables = [];
      if (sel != null) {
        tables = await repo.getTablesByHall(sel);
      }
      setState(() {
        _halls = halls;
        _selectedHallId = sel;
        _tables = tables;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onSelectHall(String hallId) async {
    if (hallId == _selectedHallId) return;
    setState(() => _loading = true);
    try {
      final tables = await repo.getTablesByHall(hallId);
      setState(() {
        _selectedHallId = hallId;
        _tables = tables;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_selectedHallId == null) return;
    final tables = await repo.getTablesByHall(_selectedHallId!);
    setState(() => _tables = tables);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'busy':
        return 'Band';
      case 'reserved':
        return 'Bron';
      case 'closed':
        return 'Yopiq';
      case 'open':
      default:
        return 'Bo‘sh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        title: const Text('Zallar & Stollar'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔹 Hall chiplari
          SizedBox(
            height: 56,
            child: _halls.isEmpty
                ? const Center(child: Text('Zallar topilmadi'))
                : ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final h = _halls[i];
                final selected = h.id == _selectedHallId;
                return ChoiceChip(
                  label: Text(
                      h.name.isEmpty ? 'Nomsiz zal' : h.name),
                  selected: selected,
                  onSelected: (_) => _onSelectHall(h.id),
                  selectedColor: Colors.blue.shade100,
                );
              },
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemCount: _halls.length,
            ),
          ),

          // 🔹 Oddiy DataTable
          Expanded(
            child: _tables.isEmpty
                ? const Center(child: Text('Stollar topilmadi'))
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                border: TableBorder.all(
                    color: Colors.grey.shade300),
                columns: const [
                  DataColumn(label: Text("Stol nomi")),
                  DataColumn(label: Text("Status")),
                  DataColumn(label: Text("Mehmonlar")),
                  DataColumn(label: Text("Sig‘imi")),
                ],
                rows: _tables.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.title)),
                      DataCell(Text(_statusLabel(t.status))),
                      DataCell(Text("${t.guestCount}")),
                      DataCell(Text("${t.capacity}")),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
