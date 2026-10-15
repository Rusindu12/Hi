import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/errors/app_exception.dart';

/// Downloads a catalogue item's file into app storage.
///
/// Two transports behind one interface:
///   * **Firebase Storage** (`storagePath` set, Firebase on) — resumable and
///     cheap; used for content SriEdu is licensed to host.
///   * **Direct HTTPS** (`sourceUrl` set, no Firebase) — used for openly
///     licensed files on a public host.
///
/// Official government titles are never routed here: their `rights` value is
/// `official_link`, so the UI opens them in a browser instead. See
/// docs/CONTENT_POLICY.md.
class StorageFileSource {
  StorageFileSource({FirebaseStorage? storage, Dio? dio})
      : _storage = storage,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
              ),
            );

  /// Lazily resolved so the class can be constructed with Firebase disabled.
  final FirebaseStorage? _storage;
  final Dio _dio;

  FirebaseStorage get _bucket => _storage ?? FirebaseStorage.instance;

  /// Downloads [storagePath] (Firebase) or [url] (HTTPS) to [destination].
  ///
  /// Returns the number of bytes written. [onProgress] receives 0.0–1.0.
  Future<int> download({
    required String destinationPath,
    required String? storagePath,
    required String url,
    void Function(double progress)? onProgress,
  }) async {
    // Bundled payload: a file shipped inside the APK (the generated sample
    // textbook). Copied out of the asset bundle on first use so the reader has a
    // real file path and works with no network at all.
    if (storagePath != null && storagePath.startsWith(assetPrefix)) {
      return _copyFromAsset(
        assetPath: storagePath.substring(assetPrefix.length),
        destinationPath: destinationPath,
        onProgress: onProgress,
      );
    }

    final bool useStorage = storagePath != null &&
        storagePath.isNotEmpty &&
        AppConfig.useFirebase;

    try {
      if (useStorage) {
        return await _downloadFromStorage(
          storagePath: storagePath,
          destinationPath: destinationPath,
          onProgress: onProgress,
        );
      }
      return await _downloadOverHttp(
        url: url,
        destinationPath: destinationPath,
        onProgress: onProgress,
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stack) {
      throw NetworkException(
        'download failed for $destinationPath',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Marks a [CatalogueItem.storagePath] that points inside the Flutter asset
  /// bundle rather than at a bucket.
  static const String assetPrefix = 'asset:';

  Future<int> _copyFromAsset({
    required String assetPath,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final File file = File(destinationPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      onProgress?.call(1);
      return data.lengthInBytes;
    } on Object catch (error, stack) {
      throw StorageException(
        'bundled asset $assetPath could not be copied',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<int> _downloadFromStorage({
    required String storagePath,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final Reference ref = _bucket.ref(storagePath);
      final File file = File(destinationPath);
      await file.parent.create(recursive: true);

      final DownloadTask task = ref.writeToFile(file);
      if (onProgress != null) {
        task.snapshotEvents.listen((TaskSnapshot snapshot) {
          final int total = snapshot.totalBytes;
          if (total > 0) {
            onProgress(snapshot.bytesTransferred / total);
          }
        });
      }
      final TaskSnapshot snapshot = await task;
      return snapshot.totalBytes;
    } on FirebaseException catch (error, stack) {
      // Storage/unauthorized, storage/object-not-found, and friends.
      throw NetworkException(
        'Firebase Storage error: ${error.code}',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<int> _downloadOverHttp({
    required String url,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    if (url.trim().isEmpty) {
      throw const NotFoundException('item has no downloadable url');
    }
    final Response<dynamic> response = await _dio.download(
      url,
      destinationPath,
      onReceiveProgress: (int received, int total) {
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      },
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
      ),
    );
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw NetworkException('HTTP ${response.statusCode} for $url');
    }
    final File file = File(destinationPath);
    if (!await file.exists()) {
      throw StorageException('download produced no file at $destinationPath');
    }
    final int length = await file.length();
    debugPrint('[SriEdu] downloaded $length bytes to $destinationPath');
    return length;
  }

  /// Best-effort remote size probe, so cards can show a file size even before
  /// the first download. Returns null when the server does not advertise it.
  Future<int?> remoteSize(String url) async {
    try {
      final Response<dynamic> response = await _dio.head<void>(url);
      final Object? length = response.headers.value('content-length');
      if (length == null) {
        return null;
      }
      return int.tryParse(length.toString());
    } on Object {
      return null;
    }
  }
}
