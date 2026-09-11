class Product {
  final String id;
  final String name;
  final String? brand;
  final String? category;
  final String? color;
  final double price;
  final String? platform;
  final double? rating;
  final List<String>? tags;
  final String? imageUrl;
  final double? originalPrice;
  final double? priceMax;
  final String? evidenceId;
  final String? sourceId;

  Product({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    this.color,
    required this.price,
    this.platform,
    this.rating,
    this.tags,
    this.imageUrl,
    this.originalPrice,
    this.priceMax,
    this.evidenceId,
    this.sourceId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      priceMax: (json['price_max'] as num?)?.toDouble(),
      evidenceId: json['evidence_id']?.toString(),
      sourceId: json['source_id']?.toString(),
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString(),
      category: json['category']?.toString(),
      color: json['color']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      platform: json['platform']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      originalPrice: (json['original_price'] as num?)?.toDouble() ??
          (json['originalPrice'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'color': color,
      'price': price,
      'platform': platform,
      'rating': rating,
      'tags': tags,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'price_max': priceMax,
      'evidence_id': evidenceId,
      'source_id': sourceId,
    };
  }
}
