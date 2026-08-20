# Vendored purl-spec conformance fixtures

These JSON files are copied verbatim from the [package-url/purl-spec][spec]
repository (`tests/spec/` and `tests/types/`). They are the official
conformance suite for ECMA-427, the Package-URL specification, and follow the
[`purl-test.schema-0.2.json`][schema] test schema.

Each case carries a `test_group`:

- `required` — needed to conform with ECMA-427.
- `recommended` — guidance on how to remediate or normalize common problems
  in purl data so it passes the `required` cases.

`spec/conformance_spec.cr` runs every case in them, and lists the handful it
deliberately does not pass along with the reason. To refresh the fixtures:

```bash
base=https://raw.githubusercontent.com/package-url/purl-spec/main/tests
curl -fsSL -o spec/fixtures/purl-spec/specification-test.json "$base/spec/specification-test.json"
curl -fsSL "https://api.github.com/repos/package-url/purl-spec/contents/tests/types" |
  grep -o '"name": "[^"]*-test.json"' | cut -d'"' -f4 |
  xargs -I{} curl -fsSL -o "spec/fixtures/purl-spec/types/{}" "$base/types/{}"
```

The listing step matters: purl-spec adds new package types over time, so
looping over the files already vendored here would silently miss them.

[spec]: https://github.com/package-url/purl-spec
[schema]: https://packageurl.org/schemas/purl-test.schema-0.2.json
