// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of initialize;

/// Metadata used to label static or top-level methods that are called
/// automatically when calling static_init.run(). This class is private because
/// it shouldn't be used directly in annotations, instead use the `initMethod`
/// singleton below.
typedef dynamic _ZeroArg();
class _InitMethod implements Initializer<_ZeroArg> {
  const _InitMethod();

  @override
  initialize(_ZeroArg method) => method();
}

/// We only ever need one instance of the `_InitMethod` class, this is it.
const initMethod = const _InitMethod();
