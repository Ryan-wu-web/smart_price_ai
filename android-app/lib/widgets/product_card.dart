import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/constants.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  String _getDisplayName(String fullName) {
    if (fullName.isEmpty) return '?';
    final firstSpace = fullName.indexOf(' ');
    if (firstSpace > 0 && firstSpace <= 10) {
      return fullName.substring(0, firstSpace);
    }
    return fullName.length > 8 ? fullName.substring(0, 8) : fullName;
  }

  Widget _buildPlaceholder(double size, String productName) {
    final displayName = _getDisplayName(productName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Constants.mediumRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savings = product.originalPrice != null && product.originalPrice! > product.price
        ? product.originalPrice! - product.price
        : 0.0;

    final imageSize = (MediaQuery.of(context).size.width * 0.22).clamp(80.0, 120.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Constants.cardColor,
          borderRadius: BorderRadius.circular(Constants.largeRadius),
          boxShadow: const [Constants.shadowCard],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Constants.mediumRadius),
              child: Container(
                width: imageSize,
                height: imageSize,
                color: const Color(0xFFF5F5F5),
                child: (product.imageUrl ?? '').isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Constants.brandColor,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(imageSize, product.name);
                        },
                      )
                    : const Icon(
                        Icons.image,
                        color: Constants.secondaryTextColor,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Constants.brandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.platform ?? '未知平台',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Constants.brandColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Constants.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '¥${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Constants.accentColor,
                        ),
                      ),
                      if (product.originalPrice != null && product.originalPrice! > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '¥${product.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Constants.secondaryTextColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (savings > 0)
                    Text(
                      '省 ¥${savings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (product.rating != null)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          product.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Constants.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
