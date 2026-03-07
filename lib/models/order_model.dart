class OrderModel {
  final String id;
  final String status;
  final String vendorName;
  final double total;

  OrderModel({
    required this.id,
    required this.status,
    required this.vendorName,
    required this.total,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawTotal = json["total"];

    return OrderModel(
      id: json["_id"] ?? json["id"] ?? "",
      status: json["status"] ?? "pending",
      vendorName: json["vendor"]?["businessName"] ??
          json["vendor"]?["name"] ??
          "Vendor",
      total: rawTotal is num
          ? rawTotal.toDouble()
          : double.tryParse(rawTotal.toString()) ?? 0.0,
    );
  }
}