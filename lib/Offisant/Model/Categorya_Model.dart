class Category {
  final String id;
  final String title;
  final String printerName;
  final String printerIp;
  final List<String> subcategories;

  Category({
    required this.id,
    required this.title,
    required this.printerName,
    required this.printerIp,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'],
      title: json['title'] ?? '',
      printerName: json['printer_id']?['name'] ?? '',
      printerIp: json['printer_id']?['ip'] ?? '',
      subcategories: json['subcategories'] != null
          ? List<String>.from(json['subcategories'].map((e) => e['title']))
          : [],
    );
  }
}
