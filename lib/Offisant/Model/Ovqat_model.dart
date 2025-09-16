class Subcategory {
  final String title;

  Subcategory({required this.title});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      title: json['title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
    };
  }
}

class Ovqat {
  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String categoryName;
  final String? subcategory; // 🔹 Mahsulot subkategoriya nomi
  final String? description;
  final String? image;
  final String? unit;
  final List<Subcategory> subcategories;

  Ovqat({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    this.subcategory,
    this.description,
    this.image,
    this.unit,
    required this.subcategories,
  });

  factory Ovqat.fromJson(Map<String, dynamic> json) {
    final category = json['category_id'] ?? json['category'];

    return Ovqat(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),

      // ✅ category obyekt yoki string bo‘lishi mumkin
      categoryId: category is Map<String, dynamic>
          ? (category['_id'] ?? '')
          : category?.toString() ?? '',

      categoryName: category is Map<String, dynamic>
          ? (category['title'] ?? '')
          : (json['category_name'] ?? ''),

      subcategory: json['subcategory'],
      description: json['description'],
      image: json['image'],
      unit: json['unit'] ?? '',

      subcategories: (json['subcategories'] is List)
          ? (json['subcategories'] as List)
          .map((e) => Subcategory.fromJson(e))
          .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'category': {
        '_id': categoryId,
        'title': categoryName,
      },
      'subcategory': subcategory,
      'description': description,
      'image': image,
      'unit': unit,
      'subcategories': subcategories.map((e) => e.toJson()).toList(),
    };
  }
}
