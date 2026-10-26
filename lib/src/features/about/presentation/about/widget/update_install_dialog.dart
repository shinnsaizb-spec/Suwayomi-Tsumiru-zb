// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../data/update_installer.dart';

/// In-app update for Android: fetch the release's APK, download it with
/// progress, then hand it to the system installer.
///
/// The last step is always the system's own confirmation screen — Android gives
/// no way for a normal app to install silently — but the user never leaves the
/// app, and the file never has to be found in Downloads.
class UpdateInstallDialog extends ConsumerStatefulWidget {
  const UpdateInstallDialog({super.key});

  @override
  ConsumerState<UpdateInstallDialog> createState() =>
      _UpdateInstallDialogState();
}

class _UpdateInstallDialogState extends ConsumerState<UpdateInstallDialog> {
  UpdateApkAsset? _asset;
  bool _resolving = true;
  bool _downloading = false;
  int _received = 0;
  int? _total;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveAsset();
  }

  Future<void> _resolveAsset() async {
    try {
      final asset = await AndroidUpdateInstaller.latestApkAsset();
      if (!mounted) return;
      setState(() {
        _asset = asset;
        _resolving = false;
        if (asset == null) _error = context.l10n.updateNoApkAsset;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final asset = _asset;
    if (asset == null) return;

    // Android 8+ gates "install unknown apps" per package. Send the user to
    // that screen rather than failing with a generic error.
    if (!await AndroidUpdateInstaller.canInstallPackages()) {
      await AndroidUpdateInstaller.openInstallSettings();
      if (!mounted) return;
      setState(() => _error = context.l10n.installPermissionRequired);
      return;
    }

    setState(() {
      _downloading = true;
      _error = null;
      _received = 0;
      _total = null;
    });

    try {
      final path = await AndroidUpdateInstaller.download(
        asset,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      final launched = await AndroidUpdateInstaller.install(path);
      if (!mounted) return;
      if (launched) {
        Navigator.pop(context);
      } else {
        setState(() {
          _downloading = false;
          _error = context.l10n.updateInstallFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
      });
    }
  }

  String _megabytes(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final progress = total == null || total == 0 ? null : _received / total;

    return AlertDialog(
      title: Text(context.l10n.newUpdateAvailable),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resolving)
            Text(context.l10n.downloadingUpdate)
          else if (_downloading) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Text(
              progress == null
                  ? _megabytes(_received)
                  : '${(progress * 100).round()}%  ·  '
                        '${_megabytes(_received)} / ${_megabytes(total ?? 0)}',
            ),
          ] else if (_asset != null)
            Text(
              _asset!.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
        ElevatedButton.icon(
          onPressed: _resolving || _downloading || _asset == null
              ? null
              : _downloadAndInstall,
          icon: const Icon(Icons.system_update_alt_rounded),
          label: Text(context.l10n.downloadAndInstall),
        ),
      ],
    );
  }
}
