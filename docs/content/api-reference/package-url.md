+++
title = "PackageURL"
description = "PackageURL class reference"
weight = 1
+++

The `Purl::PackageURL` class represents a Package URL as defined by the purl specification (ECMA-427).

## Constructor

```crystal
Purl::PackageURL.new(
  type : String,
  namespace : String?,
  name : String,
  version : String? = nil,
  qualifiers : Hash(String, String)? = nil,
  subpath : String? = nil
)
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | `String` | Yes | Package type (e.g., `"npm"`, `"pypi"`, `"maven"`) |
| `namespace` | `String?` | Yes | Type-specific prefix (e.g., npm scope, Maven groupId). Pass `nil` if none. |
| `name` | `String` | Yes | Package name |
| `version` | `String?` | No | Package version |
| `qualifiers` | `Hash(String, String)?` | No | Extra qualifying key-value pairs |
| `subpath` | `String?` | No | Extra subpath within a package |

### Raises

- `Purl::Error` if `type` is empty or contains invalid characters
- `Purl::Error` if `name` is empty
- `Purl::Error` if any qualifier key is invalid

### Example

```crystal
purl = Purl::PackageURL.new(
  "maven",
  "org.apache.commons",
  "commons-lang3",
  "3.12.0",
  qualifiers: {"packaging" => "jar"},
  subpath: "lib"
)
```

## Properties

All properties are readable and writable:

| Property | Type | Description |
|----------|------|-------------|
| `type` | `String` | Package type, always lowercase |
| `namespace` | `String?` | Package namespace |
| `name` | `String` | Package name |
| `version` | `String?` | Package version |
| `qualifiers` | `Hash(String, String)?` | Qualifier key-value pairs |
| `subpath` | `String?` | Subpath within the package |

## Class Methods

### `.parse(purl_string : String) : PackageURL`

Parses a Package URL string and returns a `PackageURL` instance.

Follows the right-to-left parsing algorithm specified by the purl spec.

```crystal
purl = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
purl.type      # => "npm"
purl.namespace # => "@angular"
purl.name      # => "animation"
purl.version   # => "12.3.1"
```

**Raises:** `Purl::Error` if the string is not a valid Package URL.

## Instance Methods

### `#to_s : String`

Returns the Package URL as a normalized string in purl format.

```crystal
purl = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1")
purl.to_s  # => "pkg:npm/%40angular/animation@12.3.1"
```

Qualifiers are sorted alphabetically by key. Components are percent-encoded per RFC 3986.

### `#==(other : PackageURL) : Bool`

Returns `true` if all normalized components match.

```crystal
a = Purl::PackageURL.parse("pkg:npm/%40babel/core@7.20.0")
b = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
a == b  # => true
```

### `#hash(hasher)`

Returns a hash value based on all components. Allows `PackageURL` to be used as a Hash key.

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SCHEME` | `"pkg"` | The purl URL scheme |
| `TYPE_PATTERN` | `/^[a-zA-Z][a-zA-Z0-9.+\-]*$/` | Valid type regex |
| `QUALIFIER_KEY_PATTERN` | `/^[a-z][a-z0-9._\-]*$/` | Valid qualifier key regex |
