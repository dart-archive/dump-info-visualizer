// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.src.init;

import 'dart:async';
import 'package:initialize/initialize.dart' show InitializerFilter;
import 'package:web_components/web_components.dart';
import 'static_initializer.dart' as init;
export 'static_initializer.dart' show deployMode;

/// Performs html import aware initialization by crawling all imported documents
/// and initializing any script tags which appear in them.
///
/// By default, this will run all [HtmlImport] initializers, followed in a 2nd
/// phase by all [CustomElement] and [CustomElementProxy] initializers. Then,
/// unless [initAll] is [false], it will run all remaining initializers.
///
/// If a [typeFilter] or [customFilter] are supplied, only one phase is ran
/// with the supplied filters.
Future initWebComponents(
    {List<Type> typeFilter,
    InitializerFilter customFilter,
    bool initAll: true}) {
  if (typeFilter != null || customFilter != null) {
    return init.run(typeFilter: typeFilter, customFilter: customFilter);
  } else {
    return init
        .run(typeFilter: [HtmlImport])
        .then((_) => init.run(typeFilter: [CustomElement, CustomElementProxy]))
        .then((_) => initAll ? init.run() : null);
  }
}
