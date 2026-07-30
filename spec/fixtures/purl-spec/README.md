# Vendored purl-spec conformance fixtures

These JSON files are copied verbatim from the [package-url/purl-spec][spec]
repository (`tests/spec/` and `tests/types/`). They are the official
conformance suite for ECMA-427, the Package-URL specification.

`spec/conformance_spec.cr` runs every case in them. To refresh the fixtures:

```bash
base=https://raw.githubusercontent.com/package-url/purl-spec/main/tests
curl -fsSL -o spec/fixtures/purl-spec/specification-test.json "$base/spec/specification-test.json"
for f in spec/fixtures/purl-spec/types/*.json; do
  curl -fsSL -o "$f" "$base/types/$(basename "$f")"
done
```

[spec]: https://github.com/package-url/purl-spec
