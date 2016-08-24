// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.build.mirrors_remover;

import 'dart:async';
import 'package:barback/barback.dart';

/// Removes `mirror_initializer.dart` and replaces it with
/// `static_initializer.dart`.
class MirrorsRemoverTransformer extends Transformer {
  MirrorsRemoverTransformer();
  MirrorsRemoverTransformer.asPlugin(BarbackSettings settings);

  bool isPrimary(AssetId id) => id.path == 'lib/src/init.dart';

  @override
  Future apply(Transform transform) async {
    String source = await transform.primaryInput.readAsString();
    source =
        source.replaceAll('mirror_initializer.dart', 'static_initializer.dart');
    transform
        .addOutput(new Asset.fromString(transform.primaryInput.id, source));
  }
}
