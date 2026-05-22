class RecognitionResult {
  final String? name;
  final String? category;
  final String? brand;
  final String? color;
  final String? material;
  final String? style;
  final Map<String, dynamic>? attributes;
  final double confidence;
  final String? imageUrl;

  RecognitionResult({
    this.name,
    this.category,
    this.brand,
    this.color,
    this.material,
    this.style,
    this.attributes,
    this.confidence = 0.0,
    this.imageUrl,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      name: json['name']?.toString(),
      category: json['category']?.toString(),
      brand: json['brand']?.toString(),
      color: json['color']?.toString(),
      material: json['material']?.toString(),
      style: json['style']?.toString(),
      attributes: json['attributes'] as Map<String, dynamic>?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'brand': brand,
      'color': color,
      'material': material,
      'style': style,
      'attributes': attributes,
      'confidence': confidence,
      'imageUrl': imageUrl,
    };
  }

  RecognitionResult copyWith({
    String? name,
    String? category,
    String? brand,
    String? color,
    String? material,
    String? style,
    Map<String, dynamic>? attributes,
    double? confidence,
    String? imageUrl,
  }) {
    return RecognitionResult(
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      material: material ?? this.material,
      style: style ?? this.style,
      attributes: attributes ?? this.attributes,
      confidence: confidence ?? this.confidence,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
