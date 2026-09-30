import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// 운동 카드의 유튜브 썸네일. 누르면 팝업에서 영상이 재생된다(09-30, youtube_embed.dart).
/// 썸네일은 youtube_id로 만든다(DB에 URL 컬럼 없음). 못 불러오면 회색 박스로 내려간다.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    super.key,
    required this.youtubeId,
    this.height,
    this.showPlayIcon = true,
  });

  final String? youtubeId;

  /// null이면 부모 높이를 채운다(AspectRatio 안에서 쓸 때).
  final double? height;

  /// 눌러서 열 수 있는 자리에만 표시한다. 상세 팝업에서는 재생되지 않으므로 숨긴다.
  final bool showPlayIcon;

  @override
  Widget build(BuildContext context) {
    final id = youtubeId;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.surfaceSubtle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (id != null && id.isNotEmpty)
              Image.network(
                'https://img.youtube.com/vi/$id/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (showPlayIcon)
              const Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.play_arrow, color: AppColors.categoryBody),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
