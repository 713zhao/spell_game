/// Embeds a third-party HTML5 game. Web builds render a real <iframe>;
/// other platforms show a "web only" placeholder until an in-app browser
/// view is wired up for them.
export 'game_iframe_web.dart' if (dart.library.io) 'game_iframe_stub.dart';
