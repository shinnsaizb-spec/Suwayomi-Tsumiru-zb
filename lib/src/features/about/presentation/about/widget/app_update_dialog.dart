// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/brand_icons.dart';
import '../../../../../constants/urls.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/launch_url_in_web.dart';
import '../../../../../utils/misc/toast/toast.dart';
import '../../../../../utils/motion/reduce_motion.dart';
import '../../../data/about_repository.dart';
import '../../../data/update_installer.dart';
import '../../../data/web_update_browser.dart';
import 'update_install_dialog.dart';

void appUpdateDialog({
  required String title,
  required String newRelease,
  required BuildContext context,
  required Toast? toast,
  String? url,
  void Function(bool skip)? onSkipChanged,
}) {
  if (kIsWeb &&
      url == null &&
      ProviderScope.containerOf(context).read(serverHostedWebProvider)) {
    return;
  }
  showDialog(
    context: context,
    builder: (context) {
      bool skip = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.newUpdateAvailable),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.versionAvailable(title, newRelease)),
              if (onSkipChanged != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skip,
                  onChanged: (v) {
                    setState(() => skip = v ?? false);
                    onSkipChanged(skip);
                  },
                  title: Text(context.l10n.skipThisVersion),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
            TextButton.icon(
              onPressed: () {
                launchUrlInWeb(
                  context,
                  url ?? AppUrls.sorayomiLatestReleaseUrl.url,
                  toast,
                );
                Navigator.pop(context);
              },
              icon: const Icon(BrandIcons.github),
              label: Text(context.l10n.gitHub),
            ),
            // Android can install it in-app; everything else keeps the release
            // page as the only option.
            if (AndroidUpdateInstaller.isSupported)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateInstallDialog(),
                    animationStyle: context.motionStyle,
                  );
                },
                icon: const Icon(Icons.system_update_alt_rounded),
                label: Text(context.l10n.downloadAndInstall),
              ),
          ],
        ),
      );
    },
    animationStyle: context.motionStyle,
  );
}

MaterialBanner webBuildReloadBanner(BuildContext context) => MaterialBanner(
  content: Text(context.l10n.serverInstalledNewTsumiru),
  actions: [
    TextButton(
      onPressed: reloadWebBuild,
      child: Text(context.l10n.reloadWebBuild),
    ),
  ],
);
