// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.build.import_inliner;

import 'dart:async';
import 'dart:collection' show LinkedHashMap;
import 'package:barback/barback.dart';
import 'package:code_transformers/assets.dart';
import 'package:code_transformers/messages/build_logger.dart';
import 'package:html/dom.dart';
import 'package:html/dom_parsing.dart' show TreeVisitor;
import 'package:path/path.dart' as path;
import 'package:source_span/source_span.dart';
import 'common.dart';
import 'import_crawler.dart';
import 'messages.dart';

/// Transformer which inlines all html imports found from the entry points. This
/// deletes all dart scripts found during the inlining, so the
/// [ScriptCompactorTransformer] should be ran first if there are any dart files
/// in html imports.
class ImportInlinerTransformer extends Transformer {
  final List<String> entryPoints;
  final List<String> bindingStartDelimiters;

  ImportInlinerTransformer(
      [this.entryPoints, this.bindingStartDelimiters = const []]);

  bool isPrimary(AssetId id) {
    if (entryPoints != null) return entryPoints.contains(id.path);
    // If no entry point is supplied, then any html file under web/ or test/ is
    // an entry point.
    return (id.path.startsWith('web/') || id.path.startsWith('test/')) &&
        id.path.endsWith('.html');
  }

  apply(Transform transform) {
    var logger = new BuildLogger(transform, convertErrorsToWarnings: true);
    return new ImportInliner(transform, transform.primaryInput.id, logger,
            bindingStartDelimiters: bindingStartDelimiters)
        .run();
  }
}

/// Helper class which actually does all the inlining of html imports for a
/// single entry point.
class ImportInliner {
  // Can be an AggregateTransform or Transform
  final transform;
  // The primary input to start from.
  final AssetId primaryInput;
  // The logger to use.
  final BuildLogger logger;
  // The start delimiters for template bindings, such as '{{' or '[['.
  final List<String> bindingStartDelimiters;

  ImportInliner(this.transform, this.primaryInput, this.logger,
      {this.bindingStartDelimiters: const []});

  Future run() {
    var crawler = new ImportCrawler(transform, primaryInput, logger);
    return crawler.crawlImports().then((imports) {
      var primaryDocument = imports[primaryInput].document;

      // Normalize urls in the entry point.
      var changed = new _UrlNormalizer(
              primaryInput, primaryInput, logger, bindingStartDelimiters)
          .visit(primaryDocument);

      // Inline things if needed, always have at least one (the entry point).
      if (imports.length > 1) {
        _inlineImports(primaryDocument, imports);
      } else if (!changed &&
          primaryDocument
                  .querySelectorAll('link[rel="import"]')
                  .where((import) => import.attributes['type'] != 'css')
                  .length ==
              0) {
        // If there were no url changes and no imports, then we are done.
        return;
      }

      primaryDocument
          .querySelectorAll('link[rel="import"]')
          .where((import) => import.attributes['type'] != 'css')
          .forEach((element) => element.remove());

      transform.addOutput(
          new Asset.fromString(primaryInput, primaryDocument.outerHtml));
    });
  }

  void _inlineImports(
      Document primaryDocument, LinkedHashMap<AssetId, ImportData> imports) {
    // Add a hidden div at the top of the body, this is where we will inline
    // all the imports.
    var importWrapper = new Element.tag('div')..attributes['hidden'] = '';
    var firstElement = primaryDocument.body.firstChild;
    if (firstElement != null) {
      primaryDocument.body.insertBefore(importWrapper, firstElement);
    } else {
      primaryDocument.body.append(importWrapper);
    }

    // Move all scripts/stylesheets/imports into the wrapper to maintain
    // ordering.
    _moveHeadToWrapper(primaryDocument, importWrapper);

    // Add all the other imports!
    imports.forEach((AssetId asset, ImportData data) {
      if (asset == primaryInput) return;
      var document = data.document;
      // Remove all dart script tags.
      document
          .querySelectorAll('script[type="$dartType"]')
          .forEach((script) => script.remove());
      // Normalize urls in attributes and inline css.
      new _UrlNormalizer(data.fromId, asset, logger, bindingStartDelimiters)
          .visit(document);
      // Replace the import with its contents by appending the nodes
      // immediately before the import one at a time, and then removing the
      // import from the document.
      var element = data.element;
      var parent = element.parent;
      document.head.nodes
          .toList(growable: false)
          .forEach((child) => parent.insertBefore(child, element));
      document.body.nodes
          .toList(growable: false)
          .forEach((child) => parent.insertBefore(child, element));
      element.remove();
    });
  }
}

/// To preserve the order of scripts with respect to inlined
/// link rel=import, we move both of those into the body before we do any
/// inlining. We do not start doing this until the first import is found
/// however, as some scripts do need to be ran in the head to work
/// properly (webcomponents.js for instance).
///
/// Note: we do this for stylesheets as well to preserve ordering with
/// respect to eachother, because stylesheets can be pulled in transitively
/// from imports.
void _moveHeadToWrapper(Document doc, Element wrapper) {
  var foundImport = false;
  for (var node in doc.head.nodes.toList(growable: false)) {
    if (node is! Element) continue;
    var tag = node.localName;
    var type = node.attributes['type'];
    var rel = node.attributes['rel'];
    if (tag == 'link' && rel == 'import') foundImport = true;
    if (!foundImport) continue;
    if (tag == 'style' ||
        tag == 'script' &&
            (type == null || type == jsType || type == dartType) ||
        tag == 'link' && (rel == 'stylesheet' || rel == 'import')) {
      // Move the node into the wrapper, where its contents will be placed.
      // This wrapper is a hidden div to prevent inlined html from causing a
      // FOUC.
      wrapper.append(node);
    }
  }
}

/// Internally adjusts urls in the html that we are about to inline.
// TODO(jakemac): Everything from here down is almost an exact copy from the
// polymer package. We should consolidate this logic by either removing it
// completely from polymer or exposing it publicly here and using that in
// polymer.
class _UrlNormalizer extends TreeVisitor {
  /// [AssetId] for the main entry point.
  final AssetId primaryInput;

  /// Asset where the original content (and original url) was found.
  final AssetId sourceId;

  /// Path to the top level folder relative to the transform primaryInput.
  /// This should just be some arbitrary # of ../'s.
  final String topLevelPath;

  /// Whether or not the normalizer has changed something in the tree.
  bool changed = false;

  // The start delimiters for template bindings, such as '{{' or '[['. If these
  // are found before the first `/` in a url, then the url will not be
  // normalized.
  final List<String> bindingStartDelimiters;

  final BuildLogger logger;

  _UrlNormalizer(AssetId primaryInput, this.sourceId, this.logger,
      this.bindingStartDelimiters)
      : primaryInput = primaryInput,
        topLevelPath = '../' * (path.url.split(primaryInput.path).length - 2);

  bool visit(Node node) {
    super.visit(node);
    return changed;
  }

  visitElement(Element node) {
    // TODO(jakemac): Support custom elements that extend html elements which
    // have url-like attributes. This probably means keeping a list of which
    // html elements support each url-like attribute.
    if (!isCustomTagName(node.localName)) {
      node.attributes.forEach((name, value) {
        if (_urlAttributes.contains(name)) {
          node.attributes[name] = _newUrl(value, node.sourceSpan);
          changed = value != node.attributes[name];
        }
      });
    }
    if (node.localName == 'style') {
      node.text = visitCss(node.text);
    } else if (node.localName == 'script' &&
        node.attributes['type'] == dartType &&
        !node.attributes.containsKey('src')) {
      changed = true;
    }
    return super.visitElement(node);
  }

  static final _url = new RegExp(r'url\(([^)]*)\)', multiLine: true);
  static final _quote = new RegExp('["\']', multiLine: true);

  /// Visit the CSS text and replace any relative URLs so we can inline it.
  // Ported from:
  // https://github.com/Polymer/vulcanize/blob/c14f63696797cda18dc3d372b78aa3378acc691f/lib/vulcan.js#L149
  // TODO(jmesserly): use csslib here instead? Parsing with RegEx is sadness.
  // Maybe it's reliable enough for finding URLs in CSS? I'm not sure.
  String visitCss(String cssText) {
    var url = spanUrlFor(sourceId, primaryInput, logger);
    var src = new SourceFile(cssText, url: url);
    return cssText.replaceAllMapped(_url, (match) {
      changed = true;
      // Extract the URL, without any surrounding quotes.
      var span = src.span(match.start, match.end);
      var href = match[1].replaceAll(_quote, '');
      href = _newUrl(href, span);
      return 'url($href)';
    });
  }

  String _newUrl(String href, SourceSpan span) {
    // We only want to parse the part of the href leading up to the first
    // folder, anything after that is not informative.
    var hrefToParse;
    var firstFolder = href.indexOf('/');
    if (firstFolder == -1) {
      hrefToParse = href;
    } else if (firstFolder == 0) {
      return href;
    } else {
      // Special case packages and assets urls.
      if (href.contains('packages/')) {
        var suffix = href.substring(href.indexOf('packages/') + 9);
        return '${topLevelPath}packages/$suffix';
      } else if (href.contains('assets/')) {
        var suffix = href.substring(href.indexOf('assets/') + 7);
        return '${topLevelPath}packages/$suffix';
      }

      hrefToParse = '${href.substring(0, firstFolder + 1)}';
    }

    // If we found a binding before the first `/`, then just return the original
    // href, we can't determine anything about it.
    if (bindingStartDelimiters.any((d) => hrefToParse.contains(d))) return href;

    Uri uri;
    // Various template systems introduce invalid characters to uris which would
    // be typically replaced at runtime. Parse errors are assumed to be caused
    // by this, and we just return the original href in that case.
    try {
      uri = Uri.parse(hrefToParse);
    } catch (e) {
      return href;
    }
    if (uri.isAbsolute) return href;
    if (uri.scheme.isNotEmpty) return href;
    if (uri.host.isNotEmpty) return href;
    if (uri.path.isEmpty) return href; // Implies standalone ? or # in URI.
    if (path.isAbsolute(hrefToParse)) return href;

    var id = uriToAssetId(sourceId, hrefToParse, logger, span);
    if (id == null) return href;

    // Build the new path, placing back any suffixes that we stripped earlier.
    var prefix =
        (firstFolder == -1) ? id.path : id.path.substring(0, id.path.length);
    var suffix = (firstFolder == -1) ? '' : href.substring(firstFolder);
    var newPath = '$prefix$suffix';

    if (newPath.startsWith('lib/')) {
      return '${topLevelPath}packages/${id.package}/${newPath.substring(4)}';
    }

    if (newPath.startsWith('asset/')) {
      return '${topLevelPath}assets/${id.package}/${newPath.substring(6)}';
    }

    if (primaryInput.package != id.package) {
      // Technically we shouldn't get there
      logger.error(
          internalErrorDontKnowHowToImport
              .create({'target': id, 'source': primaryInput, 'extra': ''}),
          span: span);
      return href;
    }

    var builder = path.url;
    return builder.normalize(builder.relative(builder.join('/', newPath),
        from: builder.join('/', builder.dirname(primaryInput.path))));
  }
}

/// Returns true if this is a valid custom element name. See:
/// <http://w3c.github.io/webcomponents/spec/custom/#dfn-custom-element-type>
bool isCustomTagName(String name) {
  if (name == null || !name.contains('-')) return false;
  return !invalidTagNames.containsKey(name);
}

/// These names have meaning in SVG or MathML, so they aren't allowed as custom
/// tags. See [isCustomTagName].
const invalidTagNames = const {
  'annotation-xml': '',
  'color-profile': '',
  'font-face': '',
  'font-face-src': '',
  'font-face-uri': '',
  'font-face-format': '',
  'font-face-name': '',
  'missing-glyph': '',
};

/// HTML attributes that expect a URL value.
/// <http://dev.w3.org/html5/spec/section-index.html#attributes-1>
///
/// Every one of these attributes is a URL in every context where it is used in
/// the DOM. The comments show every DOM element where an attribute can be used.
///
/// The _* version of each attribute is also supported, see http://goo.gl/5av8cU
const _urlAttributes = const [
  'action',
  '_action', // in form
  'background',
  '_background', // in body
  'cite',
  '_cite', // in blockquote, del, ins, q
  'data',
  '_data', // in object
  'formaction',
  '_formaction', // in button, input
  'href',
  '_href', // in a, area, link, base, command
  'icon',
  '_icon', // in command
  'manifest',
  '_manifest', // in html
  'poster',
  '_poster', // in video
  'src',
  '_src', // in audio, embed, iframe, img, input, script, source, track,video
];
