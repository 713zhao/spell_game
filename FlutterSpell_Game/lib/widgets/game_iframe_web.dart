import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Embeds a third-party HTML5 game via an <iframe>, registered once per
/// distinct URL as a Flutter web platform view.
class GameIframe extends StatelessWidget {
  final String htmlUrl;

  const GameIframe({Key? key, required this.htmlUrl}) : super(key: key);

  static final Set<String> _registeredViewTypes = {};

  @override
  Widget build(BuildContext context) {
    final viewType = 'game-iframe-${htmlUrl.hashCode}';
    if (_registeredViewTypes.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = html.IFrameElement()
          ..src = htmlUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'autoplay; fullscreen; gamepad';
        return iframe;
      });
    }
    return HtmlElementView(viewType: viewType);
  }
}
