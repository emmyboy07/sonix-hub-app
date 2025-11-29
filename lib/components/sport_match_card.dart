import 'package:flutter/material.dart';

class SportMatchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onPlay;

  const SportMatchCard({required this.item, required this.onPlay, super.key});

  String formatMatchDate12hr(dynamic dateMs) {
    int dateVal = dateMs is int ? dateMs : int.tryParse(dateMs.toString()) ?? 0;
    if (dateVal < 1e12) dateVal = dateVal * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(dateVal);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final isTomorrow =
        d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    int hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    String minute = d.minute.toString().padLeft(2, '0');
    String ampm = d.hour < 12 ? 'AM' : 'PM';
    String timeStr = "$hour:$minute $ampm";
    if (isToday) return "Today, $timeStr";
    if (isTomorrow) return "Tomorrow, $timeStr";
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return "$day/$month/$year, $timeStr";
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = item['teams']?['home'] ?? {};
    final awayTeam = item['teams']?['away'] ?? {};

    // Construct badge URLs if needed
    String? homeBadgeUrl;
    String? awayBadgeUrl;

    if (homeTeam['badge'] != null && homeTeam['badge'].toString().isNotEmpty) {
      final badge = homeTeam['badge'].toString();
      homeBadgeUrl = badge.startsWith('http')
          ? badge
          : 'https://streamed.pk/api/images/badge/$badge.webp';
    }
    if (awayTeam['badge'] != null && awayTeam['badge'].toString().isNotEmpty) {
      final badge = awayTeam['badge'].toString();
      awayBadgeUrl = badge.startsWith('http')
          ? badge
          : 'https://streamed.pk/api/images/badge/$badge.webp';
    }

    final isLive =
        DateTime.now().millisecondsSinceEpoch >= item['date'] &&
        DateTime.now().millisecondsSinceEpoch <=
            item['date'] + 2 * 60 * 60 * 1000; // 2 hours duration
    final isEnded =
        DateTime.now().millisecondsSinceEpoch >
        item['date'] + 2 * 60 * 60 * 1000;
    final isUpcoming = DateTime.now().millisecondsSinceEpoch < item['date'];
    final String formattedDate = formatMatchDate12hr(item['date']);
    final String matchTitle = item['title'] ?? 'Match';
    final String homeName = homeTeam['name']?.toString().trim() ?? '';
    final String awayName = awayTeam['name']?.toString().trim() ?? '';
    final bool showTitle = homeName.isEmpty || awayName.isEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: () => onPlay(item),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: homeBadgeUrl != null
                                  ? NetworkImage(homeBadgeUrl)
                                  : const AssetImage('assets/images/icon.png')
                                        as ImageProvider,
                              radius: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              homeName.isNotEmpty ? homeName : matchTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: awayBadgeUrl != null
                                  ? NetworkImage(awayBadgeUrl)
                                  : const AssetImage('assets/images/icon.png')
                                        as ImageProvider,
                              radius: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              awayName.isNotEmpty ? awayName : matchTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTitle)
                              Text(
                                matchTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF0000),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (showTitle) const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isEnded)
                        const Text(
                          'ENDED',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (isUpcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'UPCOMING',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['category']?.toUpperCase() ?? 'SPORT',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF0000),
                        ),
                      ),
                      Text(
                        '${item['sources']?.length ?? 0} Source${item['sources']?.length == 1 ? '' : 's'} Available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            color: const Color(0xFFFF0000),
            thickness: 1.2,
            height: 0,
          ),
        ),
      ],
    );
  }
}
