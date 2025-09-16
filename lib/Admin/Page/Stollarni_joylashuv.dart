import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StolModel {
  final String id;
  final String name;
  final int number;
  final String status;
  final int capacity;
  final bool isActive;
  Offset position;
  Size size;
  bool isRound;

  StolModel({
    required this.id,
    required this.name,
    required this.number,
    required this.status,
    required this.capacity,
    required this.isActive,
    required this.position,
    required this.size,
    this.isRound = false,
  });

  factory StolModel.fromJson(Map<String, dynamic> json) {
    return StolModel(
      id: json['id'] ?? json['_id'],
      name: json['display_name'] ?? json['name'],
      number:
          json['number'] is int
              ? json['number']
              : int.tryParse(json['number']?.toString() ?? '') ??
                  int.tryParse(
                    json['name']?.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0,
      status: json['status'],
      capacity: json['capacity'] ?? 4,
      isActive: json['is_active'],
      position: Offset.zero,
      size: Size(
        (json['capacity'] ?? 4) * 20.0,
        (json['capacity'] ?? 4) * 20.0,
      ),
      isRound: (json['capacity'] ?? 4) >= 8,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'position': {'dx': position.dx, 'dy': position.dy},
    'size': {'width': size.width, 'height': size.height},
    'isRound': isRound,
  };
}

class StollarniJoylashuv extends StatefulWidget {
  final token;
  StollarniJoylashuv({required this.token});
  @override
  _StollarniJoylashuvState createState() => _StollarniJoylashuvState();
}

class _StollarniJoylashuvState extends State<StollarniJoylashuv> {
  static const String baseUrl = "https://sorab.richman.uz/api";

  Future<List<StolModel>> fetchTables() async {
    final url = Uri.parse("$baseUrl/tables/list");

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> tablesJson = json.decode(response.body);
      return tablesJson.map((json) => StolModel.fromJson(json)).toList();
    } else {
      throw Exception("Xatolik: ${response.statusCode}");
    }
  }

  Future<List<StolModel>> fetchTablesWithPositions() async {
    final url = Uri.parse("$baseUrl/tables/list");
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> tablesJson = json.decode(response.body);
      Map<String, dynamic> positionMap = {};
      return tablesJson.map((json) {
        final table = StolModel.fromJson(json);
        if (positionMap.containsKey(table.id)) {
          final posData = positionMap[table.id];
          table.position = Offset(
            posData['position']['dx'],
            posData['position']['dy'],
          );
          table.size = Size(
            posData['size']['width'],
            posData['size']['height'],
          );
          table.isRound = posData['isRound'];
        }
        return table;
      }).toList();
    } else {
      throw Exception("Xatolik: ${response.statusCode}");
    }
  }

  List<StolModel> tables = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    try {
      final fetchedTables = await fetchTables();
      final prefs = await SharedPreferences.getInstance();
      final cachedPositions = prefs.getString('table_positions');
      Map<String, dynamic> positionMap = {};

      if (cachedPositions != null) {
        positionMap = json.decode(cachedPositions);
      }

      setState(() {
        tables =
            fetchedTables.map((table) {
              if (positionMap.containsKey(table.id)) {
                final posData = positionMap[table.id];
                table.position = Offset(
                  posData['position']['dx'],
                  posData['position']['dy'],
                );
                table.size = Size(
                  posData['size']['width'],
                  posData['size']['height'],
                );
                table.isRound = posData['isRound'];
              } else {
                // Stagger initial positions to prevent overlap
                final index = fetchedTables.indexOf(table);
                table.position = Offset(
                  50.0 + (index % 5) * 150,
                  50.0 + (index ~/ 5) * 150,
                );
              }
              return table;
            }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xatolik yuz berdi: $e')));
    }
  }

  Future<void> _cachePositions() async {
    final prefs = await SharedPreferences.getInstance();
    final positionMap = {for (var table in tables) table.id: table.toJson()};
    await prefs.setString('table_positions', json.encode(positionMap));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Pozitsiyalar saqlandi')));
  }

  void _removeTable(String id) {
    setState(() {
      tables.removeWhere((table) => table.id == id);
    });
  }

  Widget _buildDraggableTable(StolModel table) {
    return Positioned(
      left: table.position.dx,
      top: table.position.dy,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Stolni o\'chirish'),
                  content: Text(
                    '${table.name} stolini o\'chirishni xohlaysizmi?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Bekor qilish'),
                    ),
                    TextButton(
                      onPressed: () {
                        _removeTable(table.id);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'O\'chirish',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
          );
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.scale == 1.0) {
              table.position += details.focalPointDelta;
            }
            if (details.scale != 1.0) {
              final newWidth = table.size.width * details.scale;
              final newHeight = table.size.height * details.scale;
              table.size = Size(
                newWidth.clamp(40, 300),
                newHeight.clamp(40, 300),
              );
            }
          });
        },
        onScaleEnd: (details) {
          setState(() {});
        },
        child: _buildTableWithChairs(table),
      ),
    );
  }

  Widget _buildTableWithChairs(StolModel table) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: table.size.width,
          height: table.size.height,
          decoration: BoxDecoration(
            color: table.status == 'bo\'sh' ? Colors.teal : Colors.red,
            shape: table.isRound ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: table.isRound ? null : BorderRadius.circular(12),
            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                table.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${table.capacity} kishi",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        ..._buildChairsOutside(table),
      ],
    );
  }

  List<Widget> _buildChairsOutside(StolModel table) {
    List<Widget> chairs = [];
    final double radius = max(table.size.width, table.size.height) / 2 + 25;
    final Offset center = Offset(table.size.width / 2, table.size.height / 2);

    for (int i = 0; i < table.capacity; i++) {
      final angle = 2 * pi * i / table.capacity;
      final double dx = center.dx + radius * cos(angle) - 10;
      final double dy = center.dy + radius * sin(angle) - 10;

      chairs.add(
        Positioned(
          left: dx,
          top: dy,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black),
            ),
          ),
        ),
      );
    }

    return chairs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restoran Stollarini Joylash'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _cachePositions,
            tooltip: 'Pozitsiyalarni saqlash',
          ),
          IconButton(
            icon: Icon(Icons.visibility),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TablePositionViewer()),
              );
            },
            tooltip: 'Saqlangan joylashuvni ko‘rish',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  Container(
                    color: Colors.grey[200],
                    child: Stack(
                      children:
                          tables
                              .map((table) => _buildDraggableTable(table))
                              .toList(),
                    ),
                  ),
                ],
              ),
    );
  }
}

class TablePositionViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saqlangan Joylashuvlar'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }

          final prefs = snapshot.data as SharedPreferences;
          final cachedPositions = prefs.getString('table_positions');

          if (cachedPositions == null) {
            return Center(child: Text('Saqlangan joylashuvlar topilmadi'));
          }

          final Map<String, dynamic> positionMap = json.decode(cachedPositions);
          final List<StolModel> tables = [];

          positionMap.forEach((id, data) {
            tables.add(
              StolModel(
                id: id,
                name: data['name'] ?? 'Stol',
                number: data['number'] ?? 0,
                status: 'bo\'sh',
                capacity: 4,
                isActive: true,
                position: Offset(
                  data['position']['dx'],
                  data['position']['dy'],
                ),
                size: Size(data['size']['width'], data['size']['height']),
                isRound: data['isRound'] ?? false,
              ),
            );
          });

          return Container(
            color: Colors.grey[200],
            child: Stack(
              children:
                  tables.map((table) {
                    return Positioned(
                      left: table.position.dx,
                      top: table.position.dy,
                      child: _buildTableWithChairs(table),
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableWithChairs(StolModel table) {
    final double radius = max(table.size.width, table.size.height) / 2 + 25;
    final Offset center = Offset(table.size.width / 2, table.size.height / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: table.size.width,
          height: table.size.height,
          decoration: BoxDecoration(
            color: table.status == 'bo\'sh' ? Colors.teal : Colors.red,
            shape: table.isRound ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: table.isRound ? null : BorderRadius.circular(12),
            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                table.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${table.capacity} kishi",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        ...List.generate(table.capacity, (i) {
          final angle = 2 * pi * i / table.capacity;
          final double dx = center.dx + radius * cos(angle) - 10;
          final double dy = center.dy + radius * sin(angle) - 10;

          return Positioned(
            left: dx,
            top: dy,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black),
              ),
            ),
          );
        }),
      ],
    );
  }
}
