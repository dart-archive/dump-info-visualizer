// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.build.loader_replacer;

import 'dart:async';
import 'package:barback/barback.dart';

/// Removes `mirror_loader.dart` and replaces it with `static_loader.dart`.
class LoaderReplacer extends Transformer {
  LoaderReplacer.asPlugin();

  bool isPrimary(AssetId id) =>
      id.package == 'initialize' && id.path == 'lib/initialize.dart';

  Future apply(Transform transform) {
    var id = transform.primaryInput.id;
    return transform.primaryInput.readAsString().then((code) {
      transform.addOutput(new Asset.fromString(
          id, code.replaceFirst('mirror_loader.dart', 'static_loader.dart')));
    });
  }
}
