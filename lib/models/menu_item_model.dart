class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final bool available;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.available,
  });

  factory MenuItem.fromJson(Map json) {
    return MenuItem(
      id: json["_id"],
      name: json["name"],
      description: json["description"],
      price: (json["price"] as num).toDouble(),
      available: json["available"] ?? true,
    );
  }
}