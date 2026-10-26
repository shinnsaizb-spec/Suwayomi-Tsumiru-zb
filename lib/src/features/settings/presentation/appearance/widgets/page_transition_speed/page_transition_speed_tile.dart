// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/motion/page_transition_speed.dart';

/// Page / shared-element animation length.
class PageTransitionSpeedTile extends ConsumerWidget {
  const PageTransitionSpeedTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(pageTransitionSpeedProvider);
    return ListTile(
      leading: const Icon(Icons.speed_rounded),
      title: Text(context.l10n.pageTransitionSpeed),
      subtitle: Text(context.l10n.pageTransitionSpeedDescription),
      trailing: DropdownButton<PageTransitionSpeed>(
        value: speed,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) {
            ref.read(pageTransitionSpeedProvider.notifier).set(value);
          }
        },
        items: [
          for (final option in PageTransitionSpeed.values)
            DropdownMenuItem(value: option, child: Text(option.label(context))),
        ],
      ),
    );
  }
}
