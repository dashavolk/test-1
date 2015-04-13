// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.backend.metadata;

import 'platform_selector.dart';

/// Metadata for a test or test suite.
///
/// This metadata comes from declarations on the test itself; it doesn't include
/// configuration from the user.
class Metadata {
  /// The selector indicating which platforms the suite supports.
  final PlatformSelector testOn;

  /// Creates new Metadata.
  ///
  /// [testOn] defaults to [PlatformSelector.all].
  Metadata({PlatformSelector testOn})
      : testOn = testOn == null ? PlatformSelector.all : testOn;

  /// Parses metadata fields from strings.
  ///
  /// Throws a [FormatException] if any field is invalid.
  Metadata.parse({String testOn})
      : this(
          testOn: testOn == null ? null : new PlatformSelector.parse(testOn));

  /// Dezerializes the result of [Metadata.serialize] into a new [Metadata].
  Metadata.deserialize(serialized)
      : this.parse(testOn: serialized['testOn']);

  /// Return a new [Metadata] that merges [this] with [other].
  ///
  /// If the two [Metadata]s have conflicting properties, [other] wins.
  Metadata merge(Metadata other) =>
      new Metadata(testOn: testOn.intersect(other.testOn));

  /// Serializes [this] into a JSON-safe object that can be deserialized using
  /// [new Metadata.deserialize].
  serialize() => {
    'testOn': testOn == PlatformSelector.all ? null : testOn.toString()
  };
}