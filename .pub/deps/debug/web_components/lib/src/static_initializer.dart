// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Static logic for initializing web_components. This assumes the entire app
/// is reachable from the entry point.
library web_components.src.static_initializer;

import 'dart:async';
import 'package:initialize/initialize.dart' as init;

const bool deployMode = true;

Future run({List<Type> typeFilter, init.InitializerFilter customFilter}) =>
    init.run(typeFilter: typeFilter, customFilter: customFilter);
