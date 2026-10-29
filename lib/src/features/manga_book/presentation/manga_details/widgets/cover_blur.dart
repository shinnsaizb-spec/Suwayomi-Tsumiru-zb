// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/theme/brand.dart';
import '../../../../../widgets/server_image.dart';

/// The blurred cover behind the series page's header.
///
/// A real gaussian blur runs on the rasterised layer, so its cost scales with
/// the area it covers — a full-width cover at sigma 18 is one of the heaviest
/// things on this screen, and it repaints on every frame of the page
/// transition, which is exactly when frames matter.
///
/// So the image is rendered at a fraction of its size, blurred with a
/// proportionally smaller sigma, and scaled back up. The GPU filters a tiny
/// texture instead of a full-screen one and the magnification is free; the
/// result is the same soft wash at a fraction of the cost. The
/// [RepaintBoundary] keeps that layer intact while the page slides, so the
/// transition only translates it instead of re-running the blur.
class CoverBlur extends StatelessWidget {
  const CoverBlur({super.key, required this.imageUrl, this.sigma = 18});

  final String? imageUrl;

  /// Blur strength at full size. Applied at 1/[downscale] inside.
  final double sigma;

  /// How much the blurred copy is shrunk before filtering.
  static const double _downscale = 8;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isBlank) return const SizedBox.shrink();
    final neutral = BrandColors.of(context).neutral;

    return RepaintBoundary(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: _downscale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: constraints.maxWidth / _downscale,
                    height: constraints.maxHeight / _downscale,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: sigma / _downscale,
                        sigmaY: sigma / _downscale,
                      ),
                      child: ColorFiltered(
                        colorFilter: neutral
                            ? const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0, 0, 0, 1, 0, //
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              ),
                        child: ServerImage(imageUrl: url, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
