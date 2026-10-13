import 'package:flutter/services.dart';

class VolumeKeys {
  static const _channel = MethodChannel('wenku8x/volume');

  static void listen(void Function(String key) onKey) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'key') {
        onKey(call.arguments?.toString() ?? '');
      }
    });
  }

  static int _ticket = 0;
  static bool _wanted = false;

  static Future<void> setIntercept(bool value) {
    final ticket = ++_ticket;
    _wanted = value;
    return _send(value).then((_) {
      if (ticket != _ticket) return _send(_wanted);
    });
  }

  static Future<void> _send(bool value) {
    return _channel.invokeMethod('setIntercept', {'enabled': value});
  }
}
