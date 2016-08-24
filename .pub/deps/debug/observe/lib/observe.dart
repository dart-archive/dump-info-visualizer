// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library observe;

// This library contains code ported from observe-js:
// https://github.com/Polymer/observe-js/blob/0152d542350239563d0f2cad39d22d3254bd6c2a/src/observe.js
// We port what is needed for data bindings. Most of the functionality is
// ported, except where differences are needed for Dart's Observable type.

export 'src/bindable.dart';
export 'src/bind_property.dart';
export 'src/change_notifier.dart';
export 'src/change_record.dart';
export 'src/list_path_observer.dart';
export 'src/list_diff.dart' show ListChangeRecord;
export 'src/metadata.dart';
export 'src/observable.dart' hide notifyPropertyChangeHelper;
export 'src/observable_box.dart';
export 'src/observable_list.dart';
export 'src/observable_map.dart';
export 'src/observer_transform.dart';
export 'src/path_observer.dart' hide getSegmentsOfPropertyPathForTesting;
export 'src/to_observable.dart';
