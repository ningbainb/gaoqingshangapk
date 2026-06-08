import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'api_service.dart';
import 'models.dart';

class ImageService {
  Future<ImagePayload> prepareImagePayload(String path,
      {required double maxWidth, required double quality}) async {
    final file = File(path);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      throw AppException('无法读取所选图片，请重新选择。');
    }
    final _PreparedImage prepared;
    try {
      prepared = await Isolate.run(() => _prepareImageInBackground(
            bytes: bytes,
            maxWidth: maxWidth,
            quality: quality,
          ));
    } catch (_) {
      throw AppException('无法读取所选图片，请重新选择。');
    }
    return ImagePayload(
      base64: base64Encode(prepared.bytes),
      mimeType: 'image/jpeg',
      width: prepared.width,
      height: prepared.height,
      sizeInBytes: prepared.bytes.length,
    );
  }

  Future<void> saveJpegCopy(
    String sourcePath,
    String outputPath, {
    required double maxWidth,
    required double quality,
  }) async {
    final source = File(sourcePath);
    final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } on FileSystemException {
      throw AppException('无法读取所选图片，请重新选择。');
    }
    final _PreparedImage prepared;
    try {
      prepared = await Isolate.run(() => _prepareImageInBackground(
            bytes: bytes,
            maxWidth: maxWidth,
            quality: quality,
          ));
    } catch (_) {
      throw AppException('无法读取所选图片，请重新选择。');
    }
    final output = File(outputPath);
    final temp =
        File('${output.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await output.parent.create(recursive: true);
      await temp.writeAsBytes(prepared.bytes, flush: true);
      await temp.rename(output.path);
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      throw AppException('无法保存图片副本，请检查存储空间后重试。');
    }
  }
}

_PreparedImage _prepareImageInBackground({
  required Uint8List bytes,
  required double maxWidth,
  required double quality,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image data.');

  final oriented = img.bakeOrientation(decoded);
  final requestedWidth = maxWidth.round().clamp(320, 8192).toInt();
  final targetWidth =
      requestedWidth < oriented.width ? requestedWidth : oriented.width;
  final resized = oriented.width > targetWidth
      ? img.copyResize(oriented, width: targetWidth)
      : oriented;
  final jpg =
      img.encodeJpg(resized, quality: (quality.clamp(0.1, 1.0) * 100).round());

  return _PreparedImage(
    bytes: jpg,
    width: resized.width,
    height: resized.height,
  );
}

class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final List<int> bytes;
  final int width;
  final int height;
}
