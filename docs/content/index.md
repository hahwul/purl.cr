+++
title = "purl.cr"
description = "Crystal implementation of the Package URL (purl) specification"
+++

A Crystal implementation of the [Package URL (purl) specification](https://github.com/package-url/purl-spec) (ECMA-427). Parse, create, and manipulate Package URLs with type-safe Crystal code.

> Implements the full **ECMA-427** Package URL specification with type-specific normalization.

## Overview

purl.cr provides a Crystal library for working with Package URLs -- a standardized format to identify and locate software packages across different ecosystems. It supports parsing purl strings, constructing new purls programmatically, and normalizing components per the specification.

## Quick Links

- **[Getting Started](/user-guide/getting-started/)** -- Installation and your first purl
- **[Basic Usage](/user-guide/basic-usage/)** -- Creating and manipulating Package URLs
- **[API Reference](/api-reference/package-url/)** -- Complete API documentation

## Features

- **Full Spec Compliance** -- Implements the complete ECMA-427 Package URL specification
- **Parse & Generate** -- Parse purl strings and construct them from components
- **Type-Specific Normalization** -- Automatic normalization for npm, pypi, golang, deb, rpm, github, bitbucket, maven, gem, nuget, and more
- **Qualifier Support** -- Full support for key-value qualifiers with proper encoding
- **Subpath Handling** -- Parse and normalize subpath components
- **Percent-Encoding** -- Correct percent-encoding and decoding per RFC 3986

## Installation

Add purl.cr to your `shard.yml`:

```yaml
dependencies:
  purl:
    github: hahwul/purl.cr
```

Then run:

```bash
shards install
```

## Quick Example

```crystal
require "purl"

# Parse a Package URL string
purl = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
puts purl.type      # => "npm"
puts purl.namespace  # => "@angular"
puts purl.name       # => "animation"
puts purl.version    # => "12.3.1"

# Create a Package URL from components
purl = Purl::PackageURL.new("pypi", nil, "Django", "4.2.0")
puts purl.to_s  # => "pkg:pypi/django@4.2.0"
```
