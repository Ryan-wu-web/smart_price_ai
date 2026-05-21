class RecognitionResult {
  final String? category;
  final String? brand;
  final String? color;
  final String? style;
  final Map<String, dynamic>? attributes;
  final double confidence;
  final String? imageUrl;

  RecognitionResult({
    this.category,
    this.brand,
    this.color,
    this.style,
    this.attributes,
    this.confidence = 0.0,
    this.imageUrl,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      category: json['category']?.toString(),
      brand: json['brand']?.toString(),
      color: json['color']?.toString(),
      style: json['style']?.toString(),
      attributes: json['attributes'] as Map<String, dynamic>?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'brand': brand,
      'color': color,
      'style': style,
      'attributes': attributes,
      'confidence': confidence,
      'imageUrl': imageUrl,
    };
  }
}
