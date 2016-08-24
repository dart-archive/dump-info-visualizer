// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Transformer used for pub serve and pub build
library web_components.build.web_components;

import 'dart:async';
import 'package:barback/barback.dart';
import 'package:code_transformers/assets.dart';
import 'package:code_transformers/messages/build_logger.dart';
import 'package:code_transformers/resolver.dart';
import 'package:code_transformers/src/dart_sdk.dart' as dart_sdk;
import 'package:html/dom.dart' as dom;
import 'package:initialize/transformer.dart' show generateBootstrapFile;
import 'package:initialize/build/initializer_plugin.dart';
import 'package:path/path.dart' as path;
import 'package:web_components/transformer.dart';
import 'common.dart';

/// Public method that can be used inside any [Transformer] which already has a
/// [Resolver] and [Transform] to generate a bootstrap file for the
/// web_components package.
Asset generateWebComponentsBootstrap(Resolver resolver, Transform transform,
    dom.Document document, AssetId scriptId, AssetId newScriptId,
    {List<InitializerPlugin> extraPlugins: const []}) {
  var htmlImportRecorder = new HtmlImportAnnotationRecorder();
  var plugins = [htmlImportRecorder]..addAll(extraPlugins);

  // Bootstrap the application using the `initialize` package and our
  // plugins.
  var initializeBootstrap = generateBootstrapFile(
      resolver, transform, scriptId, newScriptId,
      errorIfNotFound: false, plugins: plugins);

  // Add all seen imports to the document, before the first dart script tag if
  // it exists.
  var dartScript =
      document.head.querySelector('script[type="application/dart"]');
  for (var importPath in htmlImportRecorder.importPaths) {
    var import = new dom.Element.tag('link')
      ..attributes = {'rel': 'import', 'href': importPath,};
    document.head.insertBefore(import, dartScript);
  }

  return initializeBootstrap;
}

/// A [Transformer] which runs the `initialize` transformer with
/// some special plugins and also inlines the html imports.
class WebComponentsTransformer extends Transformer {
  final Resolvers _resolvers;
  TransformOptions options;

  WebComponentsTransformer(this.options)
      : _resolvers = new Resolvers.fromMock(dart_sdk.mockSdkSources);

  bool isPrimary(AssetId id) {
    if (options.entryPoints != null) {
      return options.entryPoints.contains(id.path);
    }
    // If no entry point is supplied, then any html file under web/ or test/ is
    // an entry point.
    return (id.path.startsWith('web/') || id.path.startsWith('test/')) &&
        id.path.endsWith('.html');
  }

  Future apply(Transform transform) {
    var logger = new BuildLogger(transform);
    var primaryInput = transform.primaryInput;
    return primaryInput.readAsString().then((html) {
      // Find the dart script in the page.
      var doc = parseHtml(html, primaryInput.id.path);
      var mainScriptTag = doc.querySelector('script[type="$dartType"]');
      var scriptId = uriToAssetId(primaryInput.id,
          mainScriptTag.attributes['src'], logger, mainScriptTag.sourceSpan);

      return _resolvers.get(transform, [scriptId]).then((resolver) {
        var newScriptId = new AssetId(scriptId.package,
            '${path.url.withoutExtension(scriptId.path)}.initialize.dart');

        var bootstrap = generateWebComponentsBootstrap(
            resolver, transform, doc, scriptId, newScriptId);

        // Swap out the main script tag for the bootstrap version.
        mainScriptTag.attributes['src'] = path.url.relative(bootstrap.id.path,
            from: path.url.dirname(primaryInput.id.path));

        // Output the new document and bootstrap file.
        transform
            .addOutput(new Asset.fromString(primaryInput.id, doc.outerHtml));
        transform.addOutput(bootstrap);
        resolver.release();
      });
    });
  }
}
