# Copilot Instructions for purl.cr

This is a Crystal implementation of the [Package URL (purl) specification](https://github.com/package-url/purl-spec).

## Project Overview

- **Language**: Crystal (>= 1.11.2)
- **License**: MIT
- **Purpose**: A library to parse and generate Package URLs (purls)

## Code Style

- Use 2 spaces for indentation
- Use UTF-8 encoding
- Use LF line endings
- Trim trailing whitespace
- Insert final newline at end of files

## Project Structure

```
src/           # Source code
  purl.cr      # Main module and PackageURL class
spec/          # Test specifications
  purl_spec.cr # Tests for Purl module
  spec_helper.cr
```

## Development Commands

```bash
# Install dependencies
shards install

# Run tests
crystal spec

# Format code
crystal tool format
```

## Testing

- Tests are located in the `spec/` directory
- Use Crystal's built-in `spec` framework
- Follow existing test patterns in `spec/purl_spec.cr`

## PackageURL Format

A Package URL follows this structure:
```
type:namespace/name@version?qualifiers#subpath
```

The `PackageURL` class provides:
- `initialize`: Create a new PackageURL instance
- `to_s`: Convert to string representation
- `self.parse`: Class method to parse a purl string into a PackageURL instance

## Contributing Guidelines

- Follow Crystal conventions and idioms
- Write tests for new functionality
- Keep code simple and readable
- Document public APIs
