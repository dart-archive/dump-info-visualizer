// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Transformer used for pub serve and pub build
library web_components.transformer;

import 'package:barback/barback.dart';

export 'build/html_import_annotation_recorder.dart';
import 'build/import_inliner.dart';
export 'build/import_inliner.dart';
import 'build/script_compactor.dart';
export 'build/script_compactor.dart';
import 'build/test_compatibility.dart';
export 'build/test_compatibility.dart';
import 'build/web_components.dart';
export 'build/web_components.dart';

/// The Web Components transformer group, which internally runs several phases
/// that:
///   * Extract inlined script tags into separate files.
///   * Extract script tags from entry points and all html imports and add them
///     as dart imports in a new *.bootstrap.dart file.
///   * Run the `initialize` transformer.
///   * Inlines @HtmlImport annotations as html imports into the entry point.
///   * Inline imported html files and remove all but the main dart script tag.
///
/// At the end of these phases, this tranformer produces a single entrypoint
/// HTML file with a single Dart script that can later be compiled with dart2js.
class WebComponentsTransformerGroup implements TransformerGroup {
  final Iterable<Iterable> phases;

  WebComponentsTransformerGroup(TransformOptions options)
      : phases = createDeployPhases(options);

  WebComponentsTransformerGroup.asPlugin(BarbackSettings settings)
      : this(_parseSettings(settings));
}

/// Create deploy phases for web_components.
List<List<Transformer>> createDeployPhases(TransformOptions options,
    {String sdkDir}) {
  var phases = [];

  /// Must happen first, temporarily rewrites <link rel="x-dart-test"> tags to
  /// <script type="application/dart" _was_test></script> tags.
  phases.add([new RewriteXDartTestToScript(options.entryPoints)]);

  // Must happen before the WebComponents transformer, grabs all dart scripts
  // and combines them into one bootstrap file.
  phases.add([new ScriptCompactorTransformer(options.entryPoints)]);

  // Runs the customized version of the `initialize` transformer and inlines
  // @HtmlImport annotations.
  phases.add([new WebComponentsTransformer(options)]);

  // Inlines all html imports and removes all dart script tags in the process.
  phases.add([new ImportInlinerTransformer(options.entryPoints)]);

  /// Must happen last, rewrites
  /// <script type="application/dart" _was_test></script> tags to
  /// <link rel="x-dart-test"> tags.
  phases.add([new RewriteScriptToXDartTest(options.entryPoints)]);
  return phases;
}

/// Options used by web_components transformers
class TransformOptions {
  /// List of entrypoints paths. The paths are relative to the package root and
  /// are represented using posix style, which matches the representation used
  /// in asset ids in barback. If null, any html file under 'web/' or 'test/' is
  /// considered an entry point.
  final List<String> entryPoints;

  /// Current Barback mode.
  final bool releaseMode;

  TransformOptions(this.entryPoints, this.releaseMode);

  /// Whether an asset with [id] is an entry point HTML file.
  bool isHtmlEntryPoint(AssetId id) {
    if (id.extension != '.html') return false;

    // Note: [id.path] is a relative path from the root of a package.
    if (entryPoints == null) {
      return id.path.startsWith('web/') || id.path.startsWith('test/');
    }

    return entryPoints.contains(id.path);
  }
}

// Builds TransformOptions given some BarbackSettings
TransformOptions _parseSettings(BarbackSettings settings) {
  var args = settings.configuration;
  bool releaseMode = settings.mode == BarbackMode.RELEASE;
  var entryPoints = readFileList(args['entry_points']);
  return new TransformOptions(entryPoints, releaseMode);
}

/// Reads a file list value from the [BarbackSettings]
/// TODO(jakemac): This should also move to code_transformers.
readFileList(value) {
  if (value == null) return null;
  var files = [];
  bool error;
  if (value is List) {
    files = value;
    error = value.any((e) => e is! String);
  } else if (value is String) {
    files = [value];
    error = false;
  } else {
    error = true;
  }
  if (error) {
    print('Bad value for "entry_points" in the web_components transformer. '
        'Expected either one String or a list of Strings.');
  }
  return files;
}
