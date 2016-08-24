// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library polymer_interop.src.build.replace_polymer_js.dart;

import 'dart:async';
import 'package:barback/barback.dart';

/// Replaces `polymer.min.js` with `polymer.js` in development mode.
class ReplacePolymerJsTransformer extends Transformer {
  BarbackSettings settings;

  ReplacePolymerJsTransformer.asPlugin(this.settings);

  bool isPrimary(AssetId id) {
    if (settings.mode == BarbackMode.RELEASE) return false;
    return id.path == 'lib/src/js/polymer.html';
  }

  Future apply(Transform transform) async {
    var contents = await transform.primaryInput.readAsString();
    contents = contents.replaceFirst('polymer.min.js', 'polymer.js');
    transform
        .addOutput(new Asset.fromString(transform.primaryInput.id, contents));
  }
}
