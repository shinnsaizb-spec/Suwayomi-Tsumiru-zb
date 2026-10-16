// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../offline/data/server_connection_probe.dart';
import '../../../../offline/data/server_reachability.dart';
import '../../category/controller/edit_category_controller.dart';
import '../controller/library_manga_list.dart';

/// The library app bar's connection indicator, parked next to the search
/// button.
///
/// A spinner while the server is being probed, the offline icon after the last
/// probe failed, and a cloud otherwise. Tapping it probes again — and clears the
/// "view offline" pin plus the library reads so the shelf adopts the server's
/// answer as soon as it comes back.
///
/// It drives its own probe ([ServerConnectionProbe]) rather than reading the
/// data providers' state, because a local-first library never touches the
/// network on the serve path and so would never report anything.
class LibraryConnectionButton extends ConsumerStatefulWidget {
  const LibraryConnectionButton({super.key});

  @override
  ConsumerState<LibraryConnectionButton> createState() =>
      _LibraryConnectionButtonState();
}

class _LibraryConnectionButtonState
    extends ConsumerState<LibraryConnectionButton> {
  @override
  void initState() {
    super.initState();
    // Start probing as soon as the indicator is on screen; the probe is
    // idempotent, so mounting it in several library layouts is harmless.
    Future(() {
      if (!mounted) return;
      ref.read(serverConnectionProbeProvider.notifier).probe();
    });
  }

  Future<void> _retry() async {
    // Probe first and only touch the shelf once the server has actually
    // answered: invalidating the library reads while it is still unreachable
    // just bounced the shelf (a loading frame, then the same cached data).
    final status =
        await ref.read(serverConnectionProbeProvider.notifier).probe();
    if (status != ServerConnectionStatus.reachable) return;
    ref.read(viewOfflineNowProvider.notifier).set(false);
    ref.invalidate(libraryMangaListProvider);
    ref.invalidate(categoryControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serverConnectionProbeProvider);
    final unreachable = status == ServerConnectionStatus.unreachable ||
        ref.watch(serverUnreachableProvider);

    if (status == ServerConnectionStatus.connecting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: unreachable
          ? 'Server unreachable - tap to retry'
          : 'Connected - tap to refresh',
      icon: Icon(
        unreachable ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
        color: unreachable ? Theme.of(context).colorScheme.error : null,
      ),
      onPressed: _retry,
    );
  }
}
