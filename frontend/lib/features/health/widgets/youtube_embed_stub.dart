import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';

/// Widget tests and non-Web builds keep the playback frame layout without a browser iframe.
class YouTubeEmbed extends StatelessWidget {
  const YouTubeEmbed({super.key, required this.youtubeId});

  final String youtubeId;

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.textPrimary,
    child: Center(
      child: Icon(Icons.play_circle_fill, color: AppColors.surface, size: 56),
    ),
  );
}
