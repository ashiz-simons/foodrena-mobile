class Vendor {
  final String id;
  final String businessName;
  final bool isOpen;
  final String? logoUrl;
  final double? lat;
  final double? lng;
  final double? rating;
  final int? ratingCount;

  Vendor({
    required this.id,
    required this.businessName,
    required this.isOpen,
    this.logoUrl,
    this.lat,
    this.lng,
    this.rating,
    this.ratingCount,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    // location: { type: "Point", coordinates: [lng, lat] }
    double? lat;
    double? lng;
    final coords = json["location"]?["coordinates"];
    if (coords is List && coords.length == 2) {
      lng = (coords[0] as num?)?.toDouble();
      lat = (coords[1] as num?)?.toDouble();
    }

    return Vendor(
      id: json["_id"] ?? json["id"] ?? "",
      businessName: json["businessName"] ?? "",
      isOpen: json["isOpen"] ?? false,
      logoUrl: json["logo"]?["url"],
      lat: lat,
      lng: lng,
      rating: (json["rating"] as num?)?.toDouble(),
      ratingCount: (json["ratingCount"] as num?)?.toInt(),
    );
  }
}