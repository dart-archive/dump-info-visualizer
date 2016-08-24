// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.build.html_import_recorder_inliner;

import 'package:analyzer/src/generated/element.dart';
import 'package:initialize/transformer.dart';
import 'package:path/path.dart' as path;
import '../src/normalize_path.dart';

/// [InitializerPlugin] for @HtmlImport annotations. This records all paths
/// seen, normalizes them relative to the entry point, and records the values in
/// [importPaths].
///
/// Note: This does nothing with the paths on its own, a separate step needs to
/// add the imports to the entry point document.
class HtmlImportAnnotationRecorder implements InitializerPlugin {
  /// All the normalized import paths that were seen.
  final Set<String> importPaths = new Set<String>();

  HtmlImportAnnotationRecorder();

  /// Applies to anything named `HtmlImport` which annotates a library.
  bool shouldApply(InitializerPluginData pluginData) {
    var annotationElement = pluginData.initializer.annotationNode.element;
    var logger = pluginData.logger;
    DartType type;
    if (annotationElement is ConstructorElement) {
      type = annotationElement.returnType;
    } else if (annotationElement is PropertyAccessorElement) {
      type = annotationElement.variable.propagatedType;
      if (type == null) {
        type = pluginData.resolver
            .evaluateConstant(annotationElement.library,
                pluginData.initializer.annotationNode.name)
            .value
            .type;
      }
    } else {
      logger.error('Unsupported annotation type. Only constructors and '
          'properties are supported as initializers.');
      return false;
    }
    if (type.name != 'HtmlImport') return false;
    if (pluginData.initializer.targetElement is! LibraryElement) {
      logger.error('Invalid HtmlImport annotation on non-library element.');
      return false;
    }
    return true;
  }

  /// Records the normalized url and returns [null] so that no [InitEntry] will
  /// be created.
  String apply(InitializerPluginData pluginData) {
    var bootstrapId = pluginData.bootstrapId;
    var logger = pluginData.logger;
    var annotation = pluginData.initializer.annotationNode;
    var annotationElement = pluginData.initializer.annotationElement;
    var element = pluginData.initializer.targetElement as LibraryElement;
    var resolver = pluginData.resolver;

    var originalImportPath;
    if (annotationElement.element is PropertyAccessorElement) {
      originalImportPath = resolver
          .evaluateConstant(element.library, annotation.name)
          .value
          .fields['filePath']
          .toStringValue();
    } else {
      assert(annotationElement.element is ConstructorElement);
      originalImportPath = resolver
          .evaluateConstant(
              element.library, annotation.arguments.arguments.first)
          .value
          .toStringValue();
    }

    var libPath;
    var segments = element.source.uri.pathSegments;
    var package = segments[0];
    if (bootstrapId.package == package &&
        bootstrapId.path.startsWith('${segments[1]}/')) {
      package = null;
      libPath = path.url.relative(
          path.url.joinAll(segments.getRange(1, segments.length)),
          from: path.url.dirname(path.url.join(bootstrapId.path)));
    } else if (segments[1] == 'lib') {
      libPath = path.url.joinAll(segments.getRange(2, segments.length));
    } else {
      logger.error('Unable to import `${element.source.uri.path}` from '
          '${bootstrapId}.');
      return null;
    }

    importPaths
        .add(normalizeHtmlImportPath(originalImportPath, package, libPath));

    // Don't emit an InitEntry.
    return null;
  }
}
