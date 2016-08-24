// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Some Transformers to maintain compatibility with the new `test` package,
/// since it doesn't use normal dart script tags in html. We get around this by
/// using two transformers:
///   - A transformer to convert <lint rel="x-dart-test"> intro dart script tags
///     so that they can be processed by the rest of the transformers normally.
///   - A second transformer to convert the output back, so that the `test`
///     package can find a <link rel="x-dart-test"> tag after all the
///     transformations are done.
library web_components.build.test_compatability.dart;

import 'dart:async';
import 'package:barback/barback.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// The name of the attribute that will be added to script tags that started out
/// as <link rel="x-dart-test"> tags.
const testAttribute = '_was_test';

/// The first transformer that should be ran, this does a query selector for
/// link[rel="x-dart-test"] and changes them to a normal dart script tag with a
/// special `_was_test` attribute so we know to change it back later on.
class RewriteXDartTestToScript extends _EntryPointOnlyTransformer {
  RewriteXDartTestToScript(List<String> entryPoints) : super(entryPoints);

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((String html) {
      var doc = parse(html);
      for (var tag in doc.querySelectorAll('link[rel="x-dart-test"]')) {
        tag.replaceWith(new Element.tag('script')
          ..attributes['type'] = 'application/dart'
          ..attributes['src'] = tag.attributes['href']
          ..attributes[testAttribute] = '');
      }
      transform.addOutput(
          new Asset.fromString(transform.primaryInput.id, doc.outerHtml));
    });
  }
}

/// The last transformer that should be ran, this does a query selector for
/// `script[type="application/dart"][_was_test]` and changes matching elements
/// back to `<link rel="x-dart-test">` tags.
class RewriteScriptToXDartTest extends _EntryPointOnlyTransformer {
  RewriteScriptToXDartTest(List<String> entryPoints) : super(entryPoints);

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((String html) {
      var doc = parse(html);
      var scripts = doc
          .querySelectorAll('script[type="application/dart"][$testAttribute]');
      for (var tag in scripts) {
        tag.replaceWith(new Element.tag('link')
          ..attributes['rel'] = 'x-dart-test'
          ..attributes['href'] = tag.attributes['src']);
      }
      transform.addOutput(
          new Asset.fromString(transform.primaryInput.id, doc.outerHtml));
    });
  }
}

/// Internal base class to encapsulate the isPrimary logic.
abstract class _EntryPointOnlyTransformer extends Transformer {
  final List<String> entryPoints;

  _EntryPointOnlyTransformer(this.entryPoints) : super();

  bool isPrimary(AssetId id) {
    if (!id.path.startsWith('test/')) return false;
    if (entryPoints != null) return entryPoints.contains(id.path);
    // If no entry point is supplied, then any html file is an entry point.
    return id.path.endsWith('.html');
  }
}
