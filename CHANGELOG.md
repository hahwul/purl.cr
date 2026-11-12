# Changelog

## Unreleased

### Breaking

- A subpath passed to the constructor is no longer percent-decoded. It is
  decoded text, like every other component, so `subpath: "50%25"` keeps the
  literal `50%25` (serialized as `#50%2525`) instead of becoming `50%`, and
  `subpath: "a%e9"` no longer raises. `.`, `..` and empty segments are still
  dropped. A purl rebuilt from its own getters is now always the same purl.
- Parsing a subpath segment that decodes to contain `/` raises
  `Purl::Error`, per how-to-parse ("Report an error if any segment contains
  a slash") and ECMA-427 5.6.7. `pkg:npm/pkg#foo%2Fbar` used to be read as
  the two segments `foo/bar`.
- `Normalizer.normalize_subpath` takes the type as its first argument.
- `otp` subpaths are lowercased: the otp type definition sets the subpath
  `case_sensitive: false`, whose valid form the schema defines as lowercase.

Correctness pass over parsing, normalization and encoding. The official
ECMA-427 conformance suite is now vendored under `spec/fixtures/purl-spec`
and run by `spec/conformance_spec.cr`.

### Fixed

- pypi names collapse each run of `-`, `_` and `.` into a single `-`, as the
  pypi type definition (PEP 503) requires: `pkg:pypi/zope.interface` is now
  `pkg:pypi/zope-interface`. Purls stored in the old form compare unequal to
  the new one.
- Trailing slashes after the name are stripped when parsing, so
  `pkg:npm/foo/` parses as `foo` instead of raising.
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
- Refreshed the vendored conformance suite to test schema 0.2, adding the ten
  package types it had never covered (`bazel`, `brew`, `chrome-extension`,
  `git`, `julia`, `opam`, `otp`, `vcpkg`, `vscode-extension`, `yocto`) and
  taking it from 468 to 586 cases.
- Component requirements from the purl type definitions are enforced: a type
  that requires a namespace rejects a purl without one (`swift`,
  `vscode-extension`, ...), and a type that prohibits one rejects a purl with
  one (`vcpkg`, `otp`, `pypi`, ...).
- Names and versions are checked against the permitted characters their type
  definition pins (`chrome-extension`), qualifiers a definition marks required
  are enforced (`julia`'s `uuid`, `swid`'s `tag_id`), and a `cpan` name may no
  longer be a module name such as `URI::PackageURL`.
- A qualifier key that is not already lowercase makes a *parsed* purl invalid,
  per ECMA-427; keys passed to the constructor are still lowercased, as the
  build algorithm requires.
- `git` purls split into a host namespace and a repository-path name, so
  `pkg:git/codeberg.org/forgejo/forgejo` keeps the name `forgejo/forgejo`.
- `npm` names and scopes keep their case: the npm type definition declares
  both case sensitive because mixed-case packages were grandfathered in.
- Added the missing case rules for `brew`, `chrome-extension`, `otp`, `pypi`
  versions, `vscode-extension` and `yocto`, and `mlflow` names now follow the
  tracking server named by `repository_url`.
- A type containing `+` is rejected: ECMA-427 limits it to ASCII letters,
  digits, `.` and `-`.
- Leading and trailing slashes around a constructed name are stripped, per
  ECMA-427 5.6.4 (`"/foo/"` names `foo`, not `%2Ffoo%2F`), and lowercasing a
  Databricks `mlflow` name no longer rewrites the `%2F` marker to `%2f`.

## v0.2.0

- Added normalization rules for npm, PyPI, Maven, Debian, and GitHub purl types
- Type-specific qualifier handling and round-trip-safe encoding
- Expanded spec coverage to 110 examples

## v0.1.0

- First release
