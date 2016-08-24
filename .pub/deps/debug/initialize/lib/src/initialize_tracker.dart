// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.test.initialize_tracker;

import 'package:initialize/initialize.dart';

// Initializer that just saves everything it sees.
class InitializeTracker implements Initializer<dynamic> {
  static final List seen = [];

  const InitializeTracker();

  @override
  void initialize(value) => seen.add(value);
}

const initializeTracker = const InitializeTracker();
