import 'dart:io';

import 'app_feedback.dart';

class OwnedFileCleaner {
  const OwnedFileCleaner({
    required Future<Directory> Function() supportDirectoryProvider,
    required Future<Directory> Function() temporaryDirectoryProvider,
  })  : _supportDirectoryProvider = supportDirectoryProvider,
        _temporaryDirectoryProvider = temporaryDirectoryProvider;

  final Future<Directory> Function() _supportDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<void> deleteCustomBackground(String? path) async {
    final cleanedPath = cleanImagePathInput(path);
    if (!await isOwnedCustomBackgroundPath(cleanedPath)) return;
    await _deleteFile(cleanedPath!);
  }

  Future<bool> isOwnedCustomBackgroundPath(String? path) async {
    final cleanedPath = cleanImagePathInput(path);
    if (cleanedPath == null) return false;
    final name = imagePathFileName(cleanedPath);
    if (name == null) return false;
    if (!name.startsWith('custom-background-')) return false;
    try {
      final supportDirectory = await _supportDirectoryProvider();
      final filePath = await _canonicalFileSystemPath(File(cleanedPath));
      final directoryPath = await _canonicalFileSystemPath(supportDirectory);
      return _isPathInsideDirectory(filePath, directoryPath);
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteTransientImageFiles(Iterable<String?> paths) async {
    for (final path in paths) {
      await deleteOwnedTransientImageFile(path);
    }
    try {
      final cacheDir = await _temporaryDirectoryProvider();
      if (!await cacheDir.exists()) return;
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final name = imagePathFileName(entity.path);
        if (name == null) continue;
        if (_hasTransientImageName(name)) {
          await _deleteFile(entity.path);
        }
      }
    } catch (_) {}
  }

  Future<void> deleteOwnedTransientImageFile(String? path) async {
    final cleanedPath = cleanImagePathInput(path);
    if (!await isOwnedTransientImagePath(cleanedPath)) return;
    await _deleteFile(cleanedPath!);
  }

  Future<bool> isOwnedTransientImagePath(String? path) async {
    final cleanedPath = cleanImagePathInput(path);
    if (cleanedPath == null) return false;
    final name = imagePathFileName(cleanedPath);
    if (name == null) return false;
    if (!_hasTransientImageName(name)) return false;
    try {
      final temporaryDirectory = await _temporaryDirectoryProvider();
      final filePath = await _canonicalFileSystemPath(File(cleanedPath));
      final directoryPath = await _canonicalFileSystemPath(temporaryDirectory);
      return _isPathInsideDirectory(filePath, directoryPath);
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  bool _hasTransientImageName(String name) =>
      name.startsWith('floating-capture-') ||
      name.startsWith('clipboard-image-') ||
      name.startsWith('accessibility-capture-');

  Future<String> _canonicalFileSystemPath(FileSystemEntity entity) async {
    try {
      return await entity.resolveSymbolicLinks();
    } catch (_) {
      return entity.absolute.path;
    }
  }

  bool _isPathInsideDirectory(String path, String directoryPath) {
    final normalizedPath = cleanImagePathInput(path);
    final normalizedDirectory = cleanImagePathInput(directoryPath);
    if (normalizedPath == null || normalizedDirectory == null) return false;
    if (normalizedPath == normalizedDirectory) return true;
    final directoryPrefix = normalizedDirectory.endsWith(Platform.pathSeparator)
        ? normalizedDirectory
        : '$normalizedDirectory${Platform.pathSeparator}';
    return normalizedPath.startsWith(directoryPrefix);
  }
}
