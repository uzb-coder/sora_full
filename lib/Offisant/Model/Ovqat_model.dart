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
  final String? subcategory; // Added subcategory field
  final String? description;
  final String? image;
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
    required this.subcategories,
  });

  factory Ovqat.fromJson(Map<String, dynamic> json) {
    var subcategoriesJson = json['subcategories'] as List<dynamic>? ?? [];
    List<Subcategory> subcategoriesList = subcategoriesJson.map((e) => Subcategory.fromJson(e)).toList();

    return Ovqat(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      categoryId: json['category']?['_id'] ?? json['category_id'] ?? '',
      categoryName: json['category']?['title'] ?? json['category_name'] ?? '',
      subcategory: json['subcategory'], // Added subcategory parsing
      description: json['description'],
      image: json['image'],
      subcategories: subcategoriesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'category': {'_id': categoryId, 'title': categoryName},
      'subcategory': subcategory, // Added subcategory to JSON
      'description': description,
      'image': image,
      'subcategories': subcategories.map((e) => e.toJson()).toList(),
    };
  }
}