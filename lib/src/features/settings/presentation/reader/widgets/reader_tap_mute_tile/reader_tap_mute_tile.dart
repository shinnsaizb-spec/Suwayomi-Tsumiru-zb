// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../manga_book/presentation/reader/controller/reader_tap_mute.dart';

/// How long a tap is ignored after scrolling in the webtoon modes.
///
/// 0 turns the mute off entirely, which is the setting for people who never had
/// the misfire in the first place.
class ReaderTapMuteTile extends ConsumerWidget {
  const ReaderTapMuteTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(readerTapMuteAfterScrollProvider);
    final milliseconds = window.inMilliseconds;
    final label = milliseconds == 0
        ? context.l10n.readerTapMuteOff
        : '${(milliseconds / 1000).toStringAsFixed(1)}s';

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.touch_app_rounded),
          title: Text(context.l10n.readerTapMute),
          subtitle: Text(context.l10n.readerTapMuteDescription),
          trailing: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: milliseconds.toDouble(),
            min: 0,
            max: kReaderTapMuteMaxMs.toDouble(),
            divisions: kReaderTapMuteMaxMs ~/ 100,
            label: label,
            onChanged: (value) => ref
                .read(readerTapMuteAfterScrollProvider.notifier)
                .setMilliseconds(value.round()),
          ),
        ),
      ],
    );
  }
}
