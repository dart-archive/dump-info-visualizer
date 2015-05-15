// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dump_viz.diff_alg;

import 'info_helper.dart';

class DiffItem {
  final String kind;
  final String path;
  final int diff;

  DiffItem(this.kind, this.path, this.diff);
  bool operator ==(other) {
    return other.kind == kind && other.path == path && other.diff == diff;
  }
  int get hashCode {
    int result = 17;
    result = 37 * result + kind.hashCode;
    result = 37 * result + path.hashCode;
    result = 37 * result + diff.hashCode;
    return result;
  }
}

List<DiffItem> diff(InfoHelper before, InfoHelper after) {
  List<DiffItem> changedElements = <DiffItem>[];
  for (String path in before.joinedPaths) {
    String beforeId = before.idFromJoinedPath(path);
    int beforeSize = before.sizeOf(beforeId);
    if (beforeSize == null) continue;
    if (after.idFromJoinedPath(path) != null) {
      String afterId = after.idFromJoinedPath(path);
      int afterSize = after.sizeOf(afterId);
      if (afterSize == null) continue;
      int diff = afterSize - beforeSize;
      if (diff == 0) {
        continue;
      } else if (diff > 0) {
        changedElements.add(new DiffItem('partial-add', path, diff));
      } else {
        changedElements.add(new DiffItem('partial-remove', path, diff));
      }
    } else {
      changedElements.add(new DiffItem("full-remove", path, -beforeSize));
    }
  }

  for (String path in after.joinedPaths) {
    String afterId = after.idFromJoinedPath(path);
    int afterSize = after.sizeOf(afterId);
    if (afterSize == null) continue;
    if (before.idFromJoinedPath(path) == null) {
      changedElements.add(new DiffItem("full-add", path, afterSize));
    }
  }

  changedElements.sort((a, b) => -a.diff.abs().compareTo(b.diff.abs()));
  return changedElements;
}
