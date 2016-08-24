// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.build.script_compactor;

import 'dart:async';
import 'package:analyzer/analyzer.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/assets.dart';
import 'package:code_transformers/messages/build_logger.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;
import 'package:source_maps/refactor.dart' show TextEditTransaction;
import 'package:source_span/source_span.dart';
import 'common.dart';
import 'import_crawler.dart';
import 'messages.dart';

/// Transformer which combines all dart scripts found in html imports into one
/// new bootstrap file, and replaces the old entry point script with that file.
///
/// Note: Does not delete the original script files (it can't because the
/// imports may live in other packages). The [ImportInlinerTransformer] will not
/// copy scripts when inlining imports into your entry point to compensate for
/// this.
class ScriptCompactorTransformer extends Transformer {
  final List<String> entryPoints;

  ScriptCompactorTransformer([this.entryPoints]);

  bool isPrimary(AssetId id) {
    if (entryPoints != null) return entryPoints.contains(id.path);
    // If no entry point is supplied, then any html file under web/ or test/ is
    // an entry point.
    return (id.path.startsWith('web/') || id.path.startsWith('test/')) &&
        id.path.endsWith('.html');
  }

  apply(Transform transform) {
    var logger = new BuildLogger(transform);
    return new ScriptCompactor(transform, transform.primaryInput.id, logger)
        .run()
        .then((Asset bootstrap) {
      if (bootstrap == null) return null;
      return transform.primaryInput.readAsString().then((html) {
        var doc = parser.parse(html);
        var mainScriptTag = doc.querySelector('script[type="$dartType"]');
        mainScriptTag.attributes['src'] =
            _importPath(bootstrap.id, transform.primaryInput.id);
        mainScriptTag.text = '';

        transform.addOutput(
            new Asset.fromString(transform.primaryInput.id, doc.outerHtml));
      });
    });
  }
}

/// Helper class which does all the script compacting for a single entry point.
class ScriptCompactor {
  /// Can be an AggregateTransform or Transform
  final transform;

  /// The primary input to start from.
  final AssetId primaryInput;

  /// The logger to use.
  final BuildLogger logger;

  /// How many inline scripts were extracted.
  int inlineScriptCounter = 0;

  /// Id representing the dart script which lives in the primaryInput.
  AssetId mainScript;

  /// Ids of all the scripts found in html imports.
  final Set<AssetId> importScripts = new Set<AssetId>();

  ScriptCompactor(this.transform, this.primaryInput, this.logger);

  Future<Asset> run() {
    var crawler = new ImportCrawler(transform, primaryInput, logger);
    return crawler.crawlImports().then((imports) {
      Future extractScripts(id) =>
          _extractInlineScripts(id, imports[id].document);

      return Future.forEach(imports.keys, extractScripts).then((_) {
        if (mainScript == null) {
          logger.error(
              exactlyOneScriptPerEntryPoint.create({'url': primaryInput.path}));
          return null;
        }

        var primaryDocument = imports[primaryInput].document;
        assert(primaryDocument != null);

        // Create the new bootstrap file and return its AssetId.
        return _buildBootstrapFile(mainScript, importScripts);
      });
    });
  }

  /// Builds the bootstrap file and returns the path to it relative to
  /// [primaryInput].
  Asset _buildBootstrapFile(AssetId mainScript, Set<AssetId> importScripts) {
    var bootstrapId = new AssetId(primaryInput.package,
        primaryInput.path.replaceFirst('.html', '.bootstrap.dart'));

    var buffer = new StringBuffer();
    buffer.writeln('library ${_libraryNameFor(bootstrapId, logger)};');
    buffer.writeln();
    var i = 0;
    for (var script in importScripts) {
      var path = _importPath(script, primaryInput);
      buffer.writeln("import '$path' as i$i;");
      i++;
    }
    var mainScriptPath = _importPath(mainScript, primaryInput);
    buffer.writeln("import '$mainScriptPath' as i$i;");
    buffer.writeln();
    buffer.writeln('main() => i$i.main();');

    var bootstrap = new Asset.fromString(bootstrapId, '$buffer');
    transform.addOutput(bootstrap);
    return bootstrap;
  }

  /// Split inline scripts into their own files. We need to do this for dart2js
  /// to be able to compile them.
  ///
  /// This also validates that there weren't any duplicate scripts.
  Future _extractInlineScripts(AssetId asset, dom.Document doc) {
    var scripts = doc.querySelectorAll('script[type="$dartType"]');
    return Future.forEach(scripts, (script) {
      var src = script.attributes['src'];

      if (src != null) {
        return _addScript(
            asset, uriToAssetId(asset, src, logger, script.sourceSpan),
            span: script.sourceSpan);
      }

      final count = inlineScriptCounter++;
      var code = script.text;
      // TODO(sigmund): ensure this path is unique (dartbug.com/12618).
      var newId = primaryInput.addExtension('.$count.dart');
      if (!_hasLibraryDirective(code)) {
        var libName = _libraryNameFor(primaryInput, logger, count);
        code = "library $libName;\n$code";
      }

      // Normalize dart import paths.
      code = _normalizeDartImports(code, asset, primaryInput);

      // Write out the file and record it.
      transform.addOutput(new Asset.fromString(newId, code));

      return _addScript(asset, newId, validate: false).then((_) {
        // If in the entry point, replace the inline script with one pointing to
        // the new source file.
        if (primaryInput == asset) {
          script.text = '';
          script.attributes['src'] = path.url
              .relative(newId.path, from: path.url.dirname(primaryInput.path));
        }
      });
    });
  }

  // Normalize dart import paths when moving code from one asset to another.
  String _normalizeDartImports(String code, AssetId from, AssetId to) {
    var unit = parseDirectives(code, suppressErrors: true);
    var file = new SourceFile(code, url: spanUrlFor(from, to, logger));
    var output = new TextEditTransaction(code, file);
    for (Directive directive in unit.directives) {
      if (directive is UriBasedDirective) {
        var uri = directive.uri.stringValue;
        var span = getSpan(file, directive.uri);

        var id = uriToAssetId(from, uri, logger, span, errorOnAbsolute: false);
        if (id == null) continue;

        var primaryId = primaryInput;
        var newUri = assetUrlFor(id, primaryId, logger);
        if (newUri != uri) {
          output.edit(span.start.offset, span.end.offset, "'$newUri'");
        }
      }
    }

    if (!output.hasEdits) return code;

    // TODO(sigmund): emit source maps when barback supports it (see
    // dartbug.com/12340)
    return (output.commit()..build(file.url.toString())).text;
  }

  Future _addScript(AssetId from, AssetId scriptId,
      {bool validate: true, SourceSpan span}) {
    var validateFuture;
    if (validate && !importScripts.contains(scriptId)) {
      validateFuture = transform.hasInput(scriptId);
    } else {
      validateFuture = new Future.value(true);
    }
    return validateFuture.then((exists) {
      if (!exists) {
        logger.warning(scriptFileNotFound.create({'url': scriptId}),
            span: span);
      }

      if (from == primaryInput) {
        if (mainScript != null) {
          logger
              .error(exactlyOneScriptPerEntryPoint.create({'url': from.path}));
        }
        mainScript = scriptId;
      } else {
        importScripts.add(scriptId);
      }
    });
  }
}

/// Generate a library name for an asset.
String _libraryNameFor(AssetId id, BuildLogger logger, [int suffix]) {
  if (_isInvalidPackageName(id.package)) {
    logger.error('Invalid package name `${id.package}`. Package names should '
        'be valid dart identifiers, as indicated at '
        'https://www.dartlang.org/tools/pub/pubspec.html#name.');
  }
  var name = '${path.withoutExtension(id.path)}_'
      '${path.extension(id.path).substring(1)}';
  if (name.startsWith('lib/')) name = name.substring(4);
  validLibName(String name) {
    name = name.replaceAll(_invalidLibCharsRegex, '_');
    if (name.startsWith(_numRegex)) name = '_${name}';
    return name;
  }
  name = name.split('/').map(validLibName).join(".");
  var suffixString = suffix != null ? '_$suffix' : '';
  return '${id.package}.${name}$suffixString';
}

/// Parse [code] and determine whether it has a library directive.
bool _hasLibraryDirective(String code) =>
    parseDirectives(code, suppressErrors: true)
        .directives
        .any((d) => d is LibraryDirective);

/// Returns the dart import path to reach [id] relative to [primaryInput].
String _importPath(AssetId id, AssetId primaryInput) {
  var parts = path.url.split(id.path);
  if (parts[0] == 'lib') {
    parts[0] = id.package;
    return 'package:${path.url.joinAll(parts)}';
  }
  return path.url.relative(id.path, from: path.url.dirname(primaryInput.path));
}

bool _isInvalidPackageName(String name) {
  return name.split('.').any((part) {
    return part.isEmpty || part.contains(_invalidLibCharsRegex);
  });
}

// Constant and final variables
final _invalidLibCharsRegex = new RegExp('[^a-z0-9_]');
final _numRegex = new RegExp('[0-9]');
