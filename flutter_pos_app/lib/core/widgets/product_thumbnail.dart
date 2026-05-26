import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'product_media_image.dart';

/// Square product image for list tiles; network URL with loading + fallback.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.inventory_2_rounded,
  });

  final String? imageUrl;
  final double size;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: ProductMediaImage(
          imageUrl: imageUrl,
          fit: fit,
          placeholder: _loading(),
          errorWidget: _placeholder(),
        ),
      ),
    );
  }

  Widget _loading() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Icon(
        placeholderIcon,
        size: size * 0.45,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
