// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.html_import_annotation;

import 'dart:async';
import 'dart:html';
import 'package:initialize/initialize.dart';
import 'src/normalize_path.dart';

/// Annotation for a dart library which injects an html import into the
/// current html document. The imported file must not contain any dart script
/// tags, as they cannot be dynamically loaded.
class HtmlImport implements Initializer<LibraryIdentifier> {
  final String filePath;

  const HtmlImport(this.filePath);

  Future initialize(LibraryIdentifier library) {
    var element = new LinkElement()
      ..rel = 'import'
      ..href = normalizeHtmlImportPath(filePath, library.package, library.path);
    document.head.append(element);
    var completer = new Completer();
    var listeners = [
      element.on['load'].listen((_) => completer.complete()),
      element.on['error'].listen((_) {
        print('Error loading html import from path `$filePath`');
        completer.complete();
      }),
    ];
    return completer.future.then((_) {
      listeners.forEach((listener) => listener.cancel());
    });
  }
}
