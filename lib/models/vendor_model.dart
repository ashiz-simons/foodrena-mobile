class Vendor {
  final String id;
  final String businessName;
  final bool isOpen;

  Vendor({
    required this.id,
    required this.businessName,
    required this.isOpen,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['_id']?.toString() ?? '',
      businessName: json['businessName'] ?? '',
      isOpen: json['isOpen'] ?? true,
    );
  }
}
