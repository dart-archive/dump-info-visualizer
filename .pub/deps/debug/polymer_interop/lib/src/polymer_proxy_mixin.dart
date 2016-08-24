// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library polymer_interop.src.js_element_proxy;

import 'dart:html' show Element, DocumentFragment;
import 'dart:js' as js;
import 'package:web_components/web_components.dart'
    show CustomElementProxyMixin;

/// A mixin to make it easier to interoperate with Polymer JS elements. This
/// exposes only a subset of the public api that is most useful from external
/// elements.
///
/// Since mixins can't mixin or extend other mixins, you must also
/// mixin the [CustomElementProxyMixin] class from `web_components`. The
/// implements statement here enforces that.
abstract class PolymerProxyMixin implements CustomElementProxyMixin {
  /// The underlying Js Element's `$` property.
  js.JsObject get $ => jsElement[r'$'];

  /// By default the data bindings will be cleaned up when this custom element
  /// is detached from the document. Overriding this to return `true` will
  /// prevent that from happening.
  bool get preventDispose => jsElement['preventDispose'];
  set preventDispose(bool newValue) => jsElement['preventDispose'] = newValue;

  /// Force any pending property changes to synchronously deliver to handlers
  /// specified in the `observe` object. Note, normally changes are processed at
  /// microtask time.
  ///
  // Dart note: renamed to `deliverPropertyChanges` to be more consistent with
  // other polymer.dart elements.
  void deliverPropertyChanges() {
    jsElement.callMethod('deliverChanges', []);
  }

  /// Inject HTML which contains markup bound to this element into a target
  /// element (replacing target element content).
  DocumentFragment injectBoundHTML(String html, [Element element]) =>
      jsElement.callMethod('injectBoundHTML', [html, element]);

  /// Creates dom cloned from the given template, instantiating bindings with
  /// this element as the template model and `PolymerExpressions` as the binding
  /// delegate.
  DocumentFragment instanceTemplate(Element template) =>
      jsElement.callMethod('instanceTemplate', [template]);

  /// This method should rarely be used and only if `cancelUnbindAll` has been
  /// called to prevent element unbinding. In this case, the element's bindings
  /// will not be automatically cleaned up and it cannot be garbage collected by
  /// by the system. If memory pressure is a concern or a large amount of
  /// elements need to be managed in this way, `unbindAll` can be called to
  /// deactivate the element's bindings and allow its memory to be reclaimed.
  void unbindAll() => jsElement.callMethod('unbindAll', []);

  /// Call in `detached` to prevent the element from unbinding when it is
  /// detached from the dom. The element is unbound as a cleanup step that
  /// allows its memory to be reclaimed. If `cancelUnbindAll` is used, consider
  ///calling `unbindAll` when the element is no longer needed. This will allow
  ///its memory to be reclaimed.
  void cancelUnbindAll() => jsElement.callMethod('cancelUnbindAll', []);
}
