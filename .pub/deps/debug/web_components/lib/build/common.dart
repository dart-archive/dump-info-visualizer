// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.build.common;

import 'package:analyzer/analyzer.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/messages/build_logger.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:source_span/source_span.dart';
import 'package:path/path.dart' as path;
import 'messages.dart';

/// Generate the import url for a file described by [id], referenced by a file
/// with [sourceId].
// TODO(sigmund): this should also be in barback (dartbug.com/12610)
// TODO(jakemac): This is copied from polymer, we should move it to
// the code_transformers package so it can be shared.
String assetUrlFor(AssetId id, AssetId sourceId, BuildLogger logger,
    {bool allowAssetUrl: false}) {
  // use package: and asset: urls if possible
  if (id.path.startsWith('lib/')) {
    return 'package:${id.package}/${id.path.substring(4)}';
  }

  if (id.path.startsWith('asset/')) {
    if (!allowAssetUrl) {
      logger.error(internalErrorDontKnowHowToImport.create({
        'target': id,
        'source': sourceId,
        'extra': ' (asset urls not allowed.)'
      }));
      return null;
    }
    return 'asset:${id.package}/${id.path.substring(6)}';
  }

  // Use relative urls only if it's possible.
  if (id.package != sourceId.package) {
    logger.error("don't know how to refer to $id from $sourceId");
    return null;
  }

  var builder = path.url;
  return builder.relative(builder.join('/', id.path),
      from: builder.join('/', builder.dirname(sourceId.path)));
}

/// Gets the appropriate URL to use in a span to produce messages (e.g.
/// warnings) for users. This will attempt to format the URL in the most useful
/// way:
///
/// - If the asset is within the primary package, then use the [id.path],
///   the user will know it is a file from their own code.
/// - If the asset is from another package, then use [assetUrlFor], this will
///   likely be a "package:" url to the file in the other package, which is
///   enough for users to identify where the error is.
String spanUrlFor(AssetId id, AssetId sourceId, logger) {
  bool samePackage = id.package == sourceId.package;
  return samePackage
      ? id.path
      : assetUrlFor(id, sourceId, logger, allowAssetUrl: true);
}

/// Return the span in a file for an [AstNode].
FileSpan getSpan(SourceFile file, AstNode node) =>
    file.span(node.offset, node.end);

/// Parses an HTML file [contents] and returns a DOM-like tree.
dom.Document parseHtml(String contents, String sourcePath) {
  var parser = new HtmlParser(contents,
      encoding: 'utf8', generateSpans: true, sourceUrl: sourcePath);
  return parser.parse();
}

const String dartType = "application/dart";
const String jsType = "text/javascript";
