class Vendor {
  final String id;
  final String businessName;
  final bool isOpen;
  final String? logoUrl;

  Vendor({
    required this.id,
    required this.businessName,
    required this.isOpen,
    this.logoUrl,
  });

  factory Vendor.fromJson(
      Map<String, dynamic> json) {
    return Vendor(
      id: json["_id"] ?? json["id"] ?? "",
      businessName:
          json["businessName"] ?? "",
      isOpen: json["isOpen"] ?? false,
      logoUrl: json["logo"]?["url"],
    );
  }
}