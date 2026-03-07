class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawPrice = json["price"];

    return MenuItem(
      id: json["_id"] ?? json["id"] ?? "",
      name: json["name"] ?? "",
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice.toString()) ?? 0.0,
      description: json["description"],
      imageUrl: json["image"]?["url"] ?? json["imageUrl"],
    );
  }
}