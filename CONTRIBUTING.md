# Contributing

Thanks for your interest in purl.cr.

## Local development

```sh
shards install
crystal spec                # 110 examples
crystal tool format --check
```

Run an example end-to-end:

```sh
crystal run examples/basic.cr
```

## Submitting changes

1. Fork the repository and create a branch.
2. Add or update specs under `spec/` for any code change.
3. Make sure `crystal spec` and `crystal tool format --check` pass — CI runs both.
4. Open a pull request describing the change and linking to the relevant
   [purl-spec](https://github.com/package-url/purl-spec) section if applicable.

## Reporting issues

Please open an issue with:

- The purl string that triggers the problem.
- The expected behavior (with a link to the purl-spec section or the reference
  test suite if possible).
- The behavior purl.cr produced.

## Spec compliance

purl.cr targets the [ECMA-427 / package-url specification](https://github.com/package-url/purl-spec).
The repository's test suite mirrors the reference test vectors and type-specific
normalization rules. Bug reports referencing a specific section of the spec
land fastest.
