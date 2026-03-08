+++
title = "Errors"
description = "Error handling in purl.cr"
weight = 2
+++

## Purl::Error

All errors raised by purl.cr are instances of `Purl::Error`, which extends Crystal's `Exception` class.

```crystal
class Purl::Error < Exception
end
```

## When Errors Are Raised

### Invalid Type

```crystal
# Empty type
Purl::PackageURL.new("", nil, "name")
# => Purl::Error: Invalid type: type must not be empty

# Invalid characters in type
Purl::PackageURL.new("123invalid", nil, "name")
# => Purl::Error: Invalid type '123invalid': must start with a letter
#    and contain only ASCII letters, digits, '.', '+' or '-'
```

### Invalid Name

```crystal
# Empty name
Purl::PackageURL.new("npm", nil, "")
# => Purl::Error: Invalid name: name must not be empty
```

### Invalid Qualifier Key

```crystal
# Key starting with a digit
Purl::PackageURL.new("npm", nil, "express", nil,
  qualifiers: {"1key" => "value"})
# => Purl::Error: Invalid qualifier key '1key': must start with a letter
#    and contain only lowercase ASCII letters, digits, '.', '_' or '-'
```

### Invalid Purl String

```crystal
# Empty string
Purl::PackageURL.parse("")
# => Purl::Error: Invalid Package URL: empty string

# Missing scheme
Purl::PackageURL.parse("npm/express")
# => Purl::Error: Invalid Package URL: missing 'pkg:' scheme

# Wrong scheme
Purl::PackageURL.parse("http:npm/express")
# => Purl::Error: Invalid Package URL: scheme must be 'pkg', got 'http'

# Missing name
Purl::PackageURL.parse("pkg:npm/")
# => Purl::Error: Invalid Package URL: name must not be empty
```

## Error Handling Pattern

```crystal
require "purl"

def safe_parse(input : String) : Purl::PackageURL?
  Purl::PackageURL.parse(input)
rescue Purl::Error
  nil
end

if purl = safe_parse("pkg:npm/express@4.18.0")
  puts "Valid: #{purl.to_s}"
else
  puts "Invalid purl string"
end
```
