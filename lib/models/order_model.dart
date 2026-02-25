class OrderModel {
  final String id;
  final String status;
  final String vendorName;
  final int total;

  OrderModel({
    required this.id,
    required this.status,
    required this.vendorName,
    required this.total,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'],
      status: json['status'],
      vendorName: json['vendor']?['name'] ?? 'Vendor',
      total: json['total'],
    );
  }
}