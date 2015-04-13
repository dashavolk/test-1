// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.util.io;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../backend/operating_system.dart';
import '../runner/load_exception.dart';

/// The root directory of the Dart SDK.
final String sdkDir =
    p.dirname(p.dirname(Platform.executable));

/// The version of the Dart SDK currently in use.
final Version _sdkVersion = new Version.parse(
    new File(p.join(p.dirname(p.dirname(Platform.executable)), 'version'))
        .readAsStringSync().trim());

/// Returns the current operating system.
final OperatingSystem currentOS = (() {
  var name = Platform.operatingSystem;
  var os = OperatingSystem.findByIoName(name);
  if (os != null) return os;

  throw new UnsupportedError('Unsupported operating system "$name".');
})();

/// The root directory below which to nest temporary directories created by the
/// test runner.
///
/// This is configurable so that the test code can validate that the runner
/// cleans up after itself fully.
final _tempDir = Platform.environment.containsKey("_UNITTEST_TEMP_DIR")
    ? Platform.environment["_UNITTEST_TEMP_DIR"]
    : Directory.systemTemp.path;

/// The path to the `lib` directory of the `test` package.
String libDir({String packageRoot}) {
  var pathToIo = libraryPath(#test.util.io, packageRoot: packageRoot);
  return p.dirname(p.dirname(p.dirname(pathToIo)));
}

/// Returns whether the current Dart version supports [Isolate.kill].
final bool supportsIsolateKill = _supportsIsolateKill;
bool get _supportsIsolateKill {
  // This isn't 100% accurate, since early 1.9 dev releases didn't support
  // Isolate.kill(), but it's very unlikely anyone will be using them.
  // TODO(nweiz): remove this when we no longer support older Dart versions.
  return new VersionConstraint.parse('>=1.9.0-dev <2.0.0').allows(_sdkVersion);
}

/// Returns whether the current Dart version has a fix for issue 23084.
final bool supportsPubServe = _supportsPubServe;
bool get _supportsPubServe {
  // This isn't 100% accurate, since issue 23084 wasn't fixed in early 1.10 dev
  // releases, but it's unlikely anyone will be using them.
  // TODO(nweiz): remove this when we no longer support older Dart versions.
  return new VersionConstraint.parse('>=1.9.2 <2.0.0').allows(_sdkVersion);
}

// TODO(nweiz): Make this check [stdioType] once that works within "pub run".
/// Whether "special" strings such as Unicode characters or color escapes are
/// safe to use.
///
/// On Windows or when not printing to a terminal, only printable ASCII
/// characters should be used.
bool get canUseSpecialChars =>
    Platform.operatingSystem != 'windows' &&
    Platform.environment["_UNITTEST_USE_COLOR"] != "false";

/// Creates a temporary directory and returns its path.
String createTempDir() =>
    new Directory(_tempDir).createTempSync('dart_test_').path;

/// Creates a temporary directory and passes its path to [fn].
///
/// Once the [Future] returned by [fn] completes, the temporary directory and
/// all its contents are deleted. [fn] can also return `null`, in which case
/// the temporary directory is deleted immediately afterwards.
///
/// Returns a future that completes to the value that the future returned from
/// [fn] completes to.
Future withTempDir(Future fn(String path)) {
  return new Future.sync(() {
    var tempDir = createTempDir();
    return new Future.sync(() => fn(tempDir))
        .whenComplete(() => new Directory(tempDir).deleteSync(recursive: true));
  });
}

/// Creates a URL string for [address]:[port].
///
/// Handles properly formatting IPv6 addresses.
Uri baseUrlForAddress(InternetAddress address, int port) {
  if (address.isLoopback) {
    return new Uri(scheme: "http", host: "localhost", port: port);
  }

  // IPv6 addresses in URLs need to be enclosed in square brackets to avoid
  // URL ambiguity with the ":" in the address.
  if (address.type == InternetAddressType.IP_V6) {
    return new Uri(scheme: "http", host: "[${address.address}]", port: port);
  }

  return new Uri(scheme: "http", host: address.address, port: port);
}

/// Returns the package root for a Dart entrypoint at [path].
///
/// If [override] is passed, that's used. If the package root doesn't exist, a
/// [LoadException] is thrown.
String packageRootFor(String path, [String override]) {
  var packageRoot = override == null
      ? p.join(p.dirname(path), 'packages')
      : override;

  if (!new Directory(packageRoot).existsSync()) {
    throw new LoadException(path, "Directory $packageRoot does not exist.");
  }

  return packageRoot;
}

/// The library name must be globally unique, or the wrong library path may be
/// returned.
String libraryPath(Symbol libraryName, {String packageRoot}) {
  var lib = currentMirrorSystem().findLibrary(libraryName);
  if (lib.uri.scheme != 'package') return p.fromUri(lib.uri);

  // TODO(nweiz): is there a way to avoid assuming this is being run next to a
  // packages directory?.
  if (packageRoot == null) packageRoot = p.absolute('packages');
  return p.join(packageRoot, p.fromUri(lib.uri.path));
}