// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.mirror_loader;

import 'dart:collection' show Queue;
import 'dart:mirrors';
import 'package:path/path.dart' as path;
import 'package:initialize/initialize.dart';

final _root = currentMirrorSystem().isolate.rootLibrary;
final _libs = currentMirrorSystem().libraries;

Queue<Function> loadInitializers(
    {List<Type> typeFilter, InitializerFilter customFilter, Uri from}) {
  return new InitializationCrawler(typeFilter, customFilter, from: from).run();
}

// Crawls a library and all its dependencies for `Initializer` annotations using
// mirrors
class InitializationCrawler {
  // Set of all visited annotations, keys are the declarations that were
  // annotated, values are the annotations that have been processed.
  static final _annotationsFound =
      new Map<DeclarationMirror, Set<InstanceMirror>>();

  // If non-null, then only these annotations should be processed.
  final List<Type> typeFilter;

  // If non-null, then only annotations which return true when passed to this
  // function will be processed.
  final InitializerFilter customFilter;

  /// The library to start crawling from.
  final LibraryMirror _rootLibrary;

  /// Note: The [from] argument is only supported in the mirror_loader.dart. It
  /// is not supported statically.
  InitializationCrawler(this.typeFilter, this.customFilter, {Uri from})
      : _rootLibrary = from == null
          ? _root
          : _libs[from] {
    if (_rootLibrary == null) throw 'Unable to find library at $from.';
  }

  // The primary function in this class, invoke it to crawl and collect all the
  // annotations into a queue of init functions.
  Queue<Function> run() {
    var librariesSeen = new Set<LibraryMirror>();
    var queue = new Queue<Function>();

    _readLibraryDeclarations(_rootLibrary, librariesSeen, queue);
    return queue;
  }

  /// Returns the canonical [LibraryMirror] for a given [LibraryMirror]. This
  /// is defined as the one loaded from a `package:` url if available, otherwise
  /// it is just [lib].
  LibraryMirror _canonicalLib(LibraryMirror lib) {
    var uri = lib.uri;
    if (_isHttpStylePackageUrl(uri)) {
      var packageUri = _packageUriFor(uri);
      if (_libs.containsKey(packageUri)) return _libs[packageUri];
    }
    return lib;
  }

  /// Returns the canonical [ClassMirror] for a given [ClassMirror]. This is
  /// defined as the one that appears in the canonical owner [LibararyMirror].
  ClassMirror _canonicalClassDeclaration(ClassMirror declaration) =>
      _canonicalLib(declaration.owner).declarations[declaration.simpleName];

  /// Whether [uri] is an http URI that contains a 'packages' segment, and
  /// therefore could be converted into a 'package:' URI.
  bool _isHttpStylePackageUrl(Uri uri) {
    var uriPath = uri.path;
    return uri.scheme == _root.uri.scheme &&
        // Don't process cross-domain uris.
        uri.authority == _root.uri.authority &&
        uriPath.endsWith('.dart') &&
        (uriPath.contains('/packages/') || uriPath.startsWith('packages/'));
  }

  /// Returns a `package:` version of [uri].
  Uri _packageUriFor(Uri uri) {
    var packagePath = uri.path
        .substring(uri.path.lastIndexOf('packages/') + 'packages/'.length);
    return Uri.parse('package:$packagePath');
  }

  // Reads Initializer annotations on this library and all its dependencies in
  // post-order.
  Queue<Function> _readLibraryDeclarations(LibraryMirror lib,
      Set<LibraryMirror> librariesSeen, Queue<Function> queue) {
    lib = _canonicalLib(lib);
    if (librariesSeen.contains(lib)) return queue;
    librariesSeen.add(lib);

    // First visit all our dependencies.
    for (var dependency in lib.libraryDependencies) {
      // Skip dart: imports, they never use this package.
      var targetLibrary = dependency.targetLibrary;
      if (targetLibrary == null || targetLibrary.uri.scheme == 'dart') continue;
      _readLibraryDeclarations(dependency.targetLibrary, librariesSeen, queue);
    }

    // Second parse the library directive annotations.
    _readAnnotations(lib, queue);

    // Last, parse all class and method annotations.
    for (var declaration in _sortedDeclarationsWithMetadata(lib)) {
      _readAnnotations(declaration, queue);
      // Check classes for static annotations which are not supported
      if (declaration is ClassMirror) {
        for (var classDeclaration in declaration.declarations.values) {
          _readAnnotations(classDeclaration, queue);
        }
      }
    }

    return queue;
  }

  Iterable<DeclarationMirror> _sortedDeclarationsWithMetadata(
      LibraryMirror lib) {
    return new List()
      ..addAll(_sortDeclarations(lib, lib.declarations.values
          .where((d) => d is MethodMirror && d.metadata.isNotEmpty)))
      ..addAll(_sortDeclarations(lib, lib.declarations.values
          .where((d) => d is ClassMirror && d.metadata.isNotEmpty)));
  }

  List<DeclarationMirror> _sortDeclarations(
      LibraryMirror sourceLib, Iterable<DeclarationMirror> declarations) {
    var declarationList = declarations.toList();
    declarationList.sort((DeclarationMirror a, DeclarationMirror b) {
      // If in the same file, compare by line.
      var aSourceUri = a.location.sourceUri;
      var bSourceUri = b.location.sourceUri;
      if (aSourceUri == bSourceUri) {
        return a.location.line.compareTo(b.location.line);
      }

      // Run parts first if one is from the original library.
      if (aSourceUri == sourceLib.uri) return 1;
      if (bSourceUri == sourceLib.uri) return -1;

      // Sort parts alphabetically.
      return aSourceUri.path.compareTo(bSourceUri.path);
    });
    return declarationList;
  }

  /// Reads annotations on a [DeclarationMirror] and adds them to [_initQueue]
  /// if they are [Initializer]s.
  void _readAnnotations(DeclarationMirror declaration, Queue<Function> queue) {
    var annotations =
        declaration.metadata.where((m) => _filterMetadata(declaration, m));
    for (var meta in annotations) {
      _annotationsFound.putIfAbsent(
          declaration, () => new Set<InstanceMirror>());
      _annotationsFound[declaration].add(meta);

      // Initialize super classes first, if they are in the same library,
      // otherwise we throw an error. This can only be the case if there are
      // cycles in the imports.
      if (declaration is ClassMirror && declaration.superclass != null) {
        if (declaration.superclass.owner == declaration.owner) {
          _readAnnotations(declaration.superclass, queue);
        } else {
          // Make sure to check the canonical superclass declaration, the one
          // we get here is not always that. Specifically, this occurs if all of
          // the following conditions are met:
          //
          //   1. The current library is never loaded via a `package:` dart
          //      import anywhere in the program.
          //   2. The current library loads the superclass via a relative file
          //      import.
          //   3. The super class is imported via a `package:` import somewhere
          //      else in the program.
          var canonicalSuperDeclaration =
              _canonicalClassDeclaration(declaration.superclass);
          var superMetas = canonicalSuperDeclaration.metadata
              .where((m) => _filterMetadata(canonicalSuperDeclaration, m))
              .toList();
          if (superMetas.isNotEmpty) {
            throw new UnsupportedError(
                'We have detected a cycle in your import graph when running '
                'initializers on ${declaration.qualifiedName}. This means the '
                'super class ${canonicalSuperDeclaration.qualifiedName} has a '
                'dependency on this library (possibly transitive).');
          }
        }
      }

      var annotatedValue;
      if (declaration is ClassMirror) {
        annotatedValue = declaration.reflectedType;
      } else if (declaration is MethodMirror) {
        if (declaration.owner is! LibraryMirror) {
          // TODO(jakemac): Support static class methods.
          throw _TOP_LEVEL_FUNCTIONS_ONLY;
        }
        annotatedValue = (declaration.owner as ObjectMirror)
            .getField(declaration.simpleName).reflectee;
      } else if (declaration is LibraryMirror) {
        var package;
        var filePath;
        Uri uri = declaration.uri;
        // Convert to a package style uri if possible.
        if (_isHttpStylePackageUrl(uri)) {
          uri = _packageUriFor(uri);
        }
        if (uri.scheme == 'file' || uri.scheme.startsWith('http')) {
          filePath = path.url.relative(uri.path,
              from: _root.uri.path.endsWith('/')
                  ? _root.uri.path
                  : path.url.dirname(_root.uri.path));
        } else if (uri.scheme == 'package') {
          var segments = uri.pathSegments;
          package = segments[0];
          filePath = path.url.joinAll(segments.getRange(1, segments.length));
        } else {
          throw new UnsupportedError('Unsupported uri scheme ${uri.scheme} for '
              'library ${declaration}.');
        }
        annotatedValue =
            new LibraryIdentifier(declaration.qualifiedName, package, filePath);
      } else {
        throw _UNSUPPORTED_DECLARATION;
      }
      queue.addLast(() => meta.reflectee.initialize(annotatedValue));
    }
  }

  // Filter function that returns true only if `meta` is an `Initializer`,
  // it passes the `typeFilter` and `customFilter` if they exist, and it has not
  // yet been seen.
  bool _filterMetadata(DeclarationMirror declaration, InstanceMirror meta) {
    if (meta.reflectee is! Initializer) return false;
    if (typeFilter != null &&
        !typeFilter.any((t) => meta.reflectee.runtimeType == t)) {
      return false;
    }
    if (customFilter != null && !customFilter(meta.reflectee)) return false;
    if (!_annotationsFound.containsKey(declaration)) return true;
    if (_annotationsFound[declaration].contains(meta)) return false;
    return true;
  }
}

final _TOP_LEVEL_FUNCTIONS_ONLY = new UnsupportedError(
    'Only top level methods are supported for initializers');

final _UNSUPPORTED_DECLARATION = new UnsupportedError(
    'Initializers are only supported on libraries, classes, and top level '
    'methods');
