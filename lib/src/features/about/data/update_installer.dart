// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../constants/urls.dart';

/// An APK attached to the latest GitHub release.
class UpdateApkAsset {
  const UpdateApkAsset({required this.url, required this.fileName});

  final String url;
  final String fileName;
}

/// Downloads and installs the next release without leaving the app.
///
/// Android has no way for a normal app to install silently — the system
/// installer always asks for a confirmation — but this removes the browser
/// round trip (download, hunt for the file in Downloads, tap it).
class AndroidUpdateInstaller {
  const AndroidUpdateInstaller._();

  static const _channel = MethodChannel('tsumiru/apk_installer');

  /// Only Android has the install intent wired up; every other platform keeps
  /// the "open the release page" behaviour.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Whether this package may launch the installer. Android 8+ requires the
  /// user to allow "install unknown apps" per app; before that it is always on.
  static Future<bool> canInstallPackages() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // Nothing to do — the caller re-checks the permission afterwards.
    } on MissingPluginException {
      // Ditto.
    }
  }

  static Future<bool> install(String path) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('install', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The APK to fetch for this device, from the latest release's assets.
  ///
  /// Prefers the arm64 split (a third of the universal download), then the
  /// universal build. Returns null when the release has neither — an older
  /// release, or a release cut by the six-platform pipeline under different
  /// names.
  static Future<UpdateApkAsset?> latestApkAsset() async {
    final response = await http.get(
      Uri.parse(AppUrls.sorayomiLatestReleaseApiUrl.url),
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final assets = body['assets'];
    if (assets is! List) return null;

    final byName = <String, String>{};
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is String && url is String) byName[name] = url;
    }

    for (final suffix in const [
      '-android-arm64-v8a.apk',
      '-android-universal.apk',
    ]) {
      for (final entry in byName.entries) {
        if (entry.key.endsWith(suffix)) {
          return UpdateApkAsset(url: entry.value, fileName: entry.key);
        }
      }
    }
    return null;
  }

  /// Streams [asset] into the cache dir, reporting bytes as they arrive.
  ///
  /// The cache dir is what `file_paths.xml` exposes to the FileProvider, which
  /// is what makes the installer intent able to read the file at all.
  static Future<String> download(
    UpdateApkAsset asset, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${asset.fileName}');
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final response = await client.send(
        http.Request('GET', Uri.parse(asset.url)),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }
}
