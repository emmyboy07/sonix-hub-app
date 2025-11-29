import 'package:flutter/material.dart';

class ChannelCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onPlay;

  const ChannelCard({required this.item, required this.onPlay, super.key});

  @override
  Widget build(BuildContext context) {
    final String logo = item['logo'] ?? '';
    final String title = item['title'] ?? '';
    final String country = item['country'] ?? '';
    return GestureDetector(
      onTap: () => onPlay(item),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: logo.isNotEmpty
                  ? Image.network(
                      logo,
                      width: 90,
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.tv, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 90,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.tv, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (country.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        country,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFFF0000),
                size: 32,
              ),
              onPressed: () => onPlay(item),
              tooltip: 'Play',
            ),
          ],
        ),
      ),
    );
  }
}
