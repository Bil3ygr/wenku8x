import 'dart:ui';

class Util {
  /// img.wenku8.com 会拒绝 Dart 默认的 User-Agent，封面请求需要带上客户端标识。
  static const Map<String, String> imageHeaders = {
    "User-Agent":
        "Dalvik/2.1.0 (Linux; U; Android 11; IN2010 Build/RP1A.201005.001)",
  };

  static getCover(String aid) {
    int ia = int.parse(aid);
    return "https://img.wenku8.com/image/${ia ~/ 1000}/$aid/${aid}s.jpg";
  }

  static getJsColor(Color color) {
    final colorHex = color.value.toRadixString(16);
    String firstTwoChars = colorHex.substring(0, 2);
    String restOfString = colorHex.substring(2);
    return restOfString + firstTwoChars;
  }
}
