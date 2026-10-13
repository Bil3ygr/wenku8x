import 'package:flutter/services.dart';

class AppFonts {
  static final List<String> families = [];
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().where((path) {
      return path.startsWith('assets/fonts/') &&
          (path.endsWith('.ttf') || path.endsWith('.otf'));
    }).toList();
    for (final path in paths) {
      final fileName = path.split('/').last;
      final family = fileName.replaceAll(RegExp(r'\.(ttf|otf)$'), '');
      final loader = FontLoader(family);
      loader.addFont(rootBundle.load(path));
      await loader.load();
      families.add(family);
    }
    _loaded = true;
  }
}
