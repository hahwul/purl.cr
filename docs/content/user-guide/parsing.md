+++
title = "Parsing"
description = "Parsing Package URL strings"
weight = 3
+++

## Parsing Purl Strings

Use `Purl::PackageURL.parse` to parse a purl string into its components:

```crystal
purl = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
```

The parser follows the right-to-left parsing algorithm specified by the purl spec:

1. Split off the **subpath** from the right using `#`
2. Split off the **qualifiers** from the right using `?`
3. Split off the **scheme** from the left using `:` (must be `pkg`)
4. Remove leading slashes
5. Split off the **type** from the left using the first `/`
6. Split off the **version** from the right using `@`
7. Split off the **name** from the right using the last `/`
8. Remaining text becomes the **namespace**

## URL Variations

The parser handles several URL formats:

```crystal
# Standard format
Purl::PackageURL.parse("pkg:npm/express@4.18.0")

# With double slashes (pkg:// scheme)
Purl::PackageURL.parse("pkg://npm/express@4.18.0")

# With qualifiers
Purl::PackageURL.parse("pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie")

# With subpath
Purl::PackageURL.parse("pkg:github/hahwul/purl.cr@v0.2.0#src/purl.cr")

# Full format with all components
Purl::PackageURL.parse("pkg:maven/org.apache/commons@3.12?classifier=sources#lib")
```

## Percent-Encoding

The parser automatically decodes percent-encoded components:

```crystal
purl = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
purl.namespace  # => "@angular" (decoded from %40angular)
```

When generating a purl string with `to_s`, components are automatically percent-encoded:

```crystal
purl = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1")
purl.to_s  # => "pkg:npm/%40angular/animation@12.3.1"
```

## Error Handling

The parser raises `Purl::Error` for invalid inputs:

```crystal
begin
  Purl::PackageURL.parse("")
rescue ex : Purl::Error
  puts ex.message  # => "Invalid Package URL: empty string"
end

begin
  Purl::PackageURL.parse("invalid:string")
rescue ex : Purl::Error
  puts ex.message  # => "Invalid Package URL: scheme must be 'pkg', got 'invalid'"
end

begin
  Purl::PackageURL.parse("pkg:npm/")
rescue ex : Purl::Error
  puts ex.message  # => "Invalid Package URL: name must not be empty"
end
```
