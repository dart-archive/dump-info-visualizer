// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of initialize;

/// Implement this class to create your own initializer.
///
/// Hello world example:
///
///   class Print implements Initializer<Type> {
///     final String message;
///     const Print(this.message);
///
///     @override
///     initialize(Type t) => print('$t says `$message`');
///   }
///
///   @Print('hello world!')
///   class Foo {}
///
/// Call [run] from your main and this will print 'Foo says `hello world!`'
///
abstract class Initializer<T> {
  dynamic initialize(T target);
}

/// Typedef for a custom filter function.
typedef bool InitializerFilter(Initializer initializer);

/// When annotating libraries, this is passed to the initializer.
class LibraryIdentifier {
  // The qualified name of the library.
  final Symbol name;

  // The package this library lives in. May be null if its the same as the root
  // package.
  final String package;

  // The path to the library.
  final String path;

  const LibraryIdentifier(this.name, this.package, this.path);

  bool operator ==(LibraryIdentifier other) =>
      name == other.name && package == other.package && path == other.path;

  String toString() => '$name: $package:$path';
}
