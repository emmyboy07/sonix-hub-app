import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sonix_hub/config/app_config.dart';
import 'package:sonix_hub/config/theme.dart';

class MovieCard extends StatelessWidget {
  final String? posterPath;
  final String title;
  final double rating;
  final VoidCallback onTap;
  final bool showTitle;

  const MovieCard({
    super.key,
    required this.posterPath,
    required this.title,
    required this.rating,
    required this.onTap,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.mediumBlack,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: posterPath != null
                          ? '${AppConfig.tmdbImageBaseUrl}$posterPath'
                          : '',
                      fit: BoxFit.cover,
                      memCacheHeight: 360,
                      memCacheWidth: 240,
                      placeholder: (context, url) =>
                          Container(color: AppTheme.mediumBlack),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.mediumBlack,
                        child: Icon(Icons.movie, color: AppTheme.lightGray),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFD700),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
