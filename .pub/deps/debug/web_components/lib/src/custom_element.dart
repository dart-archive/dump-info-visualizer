// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.custom_element;

import 'dart:html' show document;
import 'package:initialize/initialize.dart';

/// Annotation which registers a custom element with the main document.
class CustomElement implements Initializer<Type> {
  /// The tag you want to register the class to handle.
  final String tag;

  /// If this element extends a native html element, then this is the tag that
  /// represents that element.
  final String extendsTag;

  const CustomElement(this.tag, {this.extendsTag});

  void initialize(Type t) =>
      document.registerElement(tag, t, extendsTag: extendsTag);
}
