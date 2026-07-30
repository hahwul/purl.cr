# Changelog

## Unreleased

Correctness pass over parsing, normalization and encoding. The official
ECMA-427 conformance suite is now vendored under `spec/fixtures/purl-spec`
and run by `spec/conformance_spec.cr`.

### Fixed

- Percent-encoding now follows ECMA-427 clause 5.4: `:` is never encoded
  (so `@sha256:...` and deb epochs such as `@1:2.4.47-2` stay readable), and
  `/` is encoded in qualifier values (`repository_url=https:%2F%2F...`).
- The version separator is located in the last path segment only, so an
  unencoded npm scope parses correctly (`pkg:npm/@babel/core`) while purls
  with no name (`pkg:cran/@0.9.1`) are still rejected.
- The version is decoded and encoded as an opaque value instead of as a path
  segment, fixing round-tripping for versions containing `/` or `%`.
- Subpaths are decoded once rather than twice, and a literal `%` in a subpath
  segment no longer turns into a segment separator on re-parse.
- Type-specific normalization no longer corrupts the `%2F` marker that stands
  for an encoded slash inside a segment (`pkg:pub/Foo%2FBar` used to become
  `foo_2fbar`).
- Added the missing case rules for `alpm`, `apk`, `bitnami`, `cpan`, `hex`,
  `luarocks` and `qpkg`.
- A blank version collapses to nil instead of serializing as a dangling `@`,
  and blank namespace and subpath segments are dropped.
- A raw `/` in a constructed name is stored as the `%2F` marker, so a
  constructed purl equals its own parsed form.
- Duplicate qualifier keys are rejected instead of silently keeping the last
  value.
- `#qualifiers` returns a copy, so mutating it can no longer break `==` and
  `#hash` for a purl already used as a Hash key.

## v0.2.0

- Added normalization rules for npm, PyPI, Maven, Debian, and GitHub purl types
- Type-specific qualifier handling and round-trip-safe encoding
- Expanded spec coverage to 110 examples

## v0.1.0

- First release
