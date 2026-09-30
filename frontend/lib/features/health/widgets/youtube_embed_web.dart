import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class YouTubeEmbed extends StatefulWidget {
  const YouTubeEmbed({super.key, required this.youtubeId});

  final String youtubeId;

  @override
  State<YouTubeEmbed> createState() => _YouTubeEmbedState();
}

class _YouTubeEmbedState extends State<YouTubeEmbed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-${widget.youtubeId}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.HTMLIFrameElement()
        ..src =
            'https://www.youtube-nocookie.com/embed/${widget.youtubeId}?rel=0&playsinline=1&autoplay=1'
        ..title = 'YouTube video player'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..setAttribute('allowfullscreen', 'true')
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
