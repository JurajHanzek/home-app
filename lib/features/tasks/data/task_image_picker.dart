import 'package:flutter/services.dart';

class PreparedTaskImage {
  const PreparedTaskImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

class TaskImagePicker {
  static const _channel = MethodChannel('app.homehub/task_images');

  static Future<PreparedTaskImage?> pick() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'pickAndCompress',
    );
    if (value == null) return null;
    return PreparedTaskImage(
      value['bytes']! as Uint8List,
      value['width']! as int,
      value['height']! as int,
    );
  }
}
