// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Contains all error and warning messages produced by web_components.
library web_components.build.messages;

import 'package:code_transformers/messages/messages.dart';

const scriptFileNotFound = const MessageTemplate(
    const MessageId('web_components', 0),
    'Script file at "%-url-%" not found.',
    'URL to a script file might be incorrect',
    '''
An error occurred trying to read a script tag on a given URL. This is often the
result of a broken URL in a `<script src="...">`.
''');

const scriptIncludedMoreThanOnce = const MessageTemplate(
    const MessageId('web_components', 1),
    'The `%-url-%` script was included more than once.',
    'Dart script file included more than once.',
    '''
Duplicate dart scripts often happen if you have multiple html imports that
include the same script. The simplest workaround for this is to move your dart
script to its own html file, and import that instead of the script (html imports
are automatically deduped).

For example:

    <script type="application/dart" src="foo.dart"></script>

Should turn into:

    <link rel="import" href="foo.html">

And `foo.html` should look like:

    <script type="application/dart" src="foo.dart"></script>
''');

const exactlyOneScriptPerEntryPoint = const MessageTemplate(
    const MessageId('web_components', 2),
    'Found either zero or multiple dart scripts in the entry point `%-url-%`. '
    'Exactly one was expected.',
    'Each entry point html file should contain exactly one dart script tag.',
    'Each entry point html file should contain exactly one dart script tag.');

const internalErrorDontKnowHowToImport = const MessageTemplate(
    const MessageId('web_components', 3),
    "internal error: don't know how to include %-target-% from"
    " %-source-%.%-extra-%",
    "Internal error: don't know how to include a URL",
    '''
Sorry, you just ran into a bug in the web_components transformer code. Please
file a bug at <https://github.com/dart-lang/web-components/issues/new>
including, if possible, some example code that can help the team reproduce the
issue.
''');

const inlineImportFail = const MessageTemplate(
    const MessageId('web_components', 4),
    'Failed to inline HTML import: %-error-%',
    'Error while inlining an import',
    '''
An error occurred while inlining an import in the web_components build. This is
often the result of a broken HTML import.

One possible cause is using an @HtmlImport containing a relative path from
within an inline script tag, see http://goo.gl/ZgrhaV. The workaround currently
is to use a `package:` url instead, move the code to a dart file, or simply
adding a real html import (since you are already in an html file).
''');
