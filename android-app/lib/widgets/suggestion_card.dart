import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'responsive_layout.dart';

class SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  const SuggestionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = ResponsiveLayout.value(context,
      small: 130.0,
      medium: 150.0,
      large: 170.0,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Constants.cardColor,
          borderRadius: BorderRadius.circular(Constants.largeRadius),
          boxShadow: const [Constants.shadowCard],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? Constants.brandColor).withOpacity(0.12),
                borderRadius: BorderRadius.circular(Constants.radiusMedium),
              ),
              child: Icon(
                icon,
                color: iconColor ?? Constants.brandColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Constants.primaryTextColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Constants.secondaryTextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
