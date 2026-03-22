class AddOn {
  final String name;
  final double price;

  const AddOn({required this.name, required this.price});

  factory AddOn.fromJson(Map<String, dynamic> j) => AddOn(
        name: j["name"] ?? "",
        price: (j["price"] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {"name": name, "price": price};
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? category;
  final List<AddOn> addOns;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.category,
    this.addOns = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawPrice = json["price"];
    final rawAddOns = json["addOns"];

    return MenuItem(
      id: json["_id"] ?? json["id"] ?? "",
      name: json["name"] ?? "",
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice.toString()) ?? 0.0,
      description: json["description"],
      imageUrl: json["image"]?["url"] ?? json["imageUrl"],
      category: json["category"],
      addOns: rawAddOns is List
          ? rawAddOns.map((a) => AddOn.fromJson(a)).toList()
          : [],
    );
  }
}