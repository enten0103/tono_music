import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/routes/app_routes.dart';

class PlaylistCard extends StatelessWidget {
  final String id;
  final String source; // 'wy' | 'tx' | 'kg'
  final String name;
  final String coverUrl;
  final String? creator;
  final int? playCount;
  const PlaylistCard({
    super.key,
    required this.id,
    required this.source,
    required this.name,
    required this.coverUrl,
    this.creator,
    this.playCount,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final double fontSize = baseStyle?.fontSize ?? 14;
    final double lineHeight = (baseStyle?.height ?? 1.2) * fontSize;
    final double titleFixedHeight = lineHeight * 2;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: () {
          Get.toNamed(
            AppRoutes.playlistDetail,
            arguments: {
              'id': id,
              'source': source,
              'name': name,
              'coverUrl': coverUrl,
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFEFEFEF),
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: SizedBox(
                height: titleFixedHeight,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    if (creator != null && creator!.isNotEmpty)
                      Flexible(
                        child: Text(
                          creator!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const Spacer(),
                    if (playCount != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, size: 14),
                          const SizedBox(width: 2),
                          Text(_fmtCount(playCount!)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static String _fmtCount(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }
}
