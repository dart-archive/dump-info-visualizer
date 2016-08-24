// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.src.normalizePath;

import 'package:path/path.dart' as path;

String normalizeHtmlImportPath(
    String filePath, String dartFilePackage, String dartFilePath) {
  // If they already supplied a packages path, just return that.
  if (filePath.startsWith('package:')) {
    return filePath.replaceFirst('package:', 'packages/');
  }

  var dartFileDir = path.url.dirname(dartFilePath);

  // Relative paths have no package supplied.
  if (dartFilePackage == null) {
    return path.url.normalize(path.url.join(dartFileDir, filePath));
  }

  // Only option left is a packages/ path.
  return path.url.normalize(
      path.url.join('packages/', dartFilePackage, dartFileDir, filePath));
}
