+++
title = "Getting Started"
description = "Installation and first steps with purl.cr"
weight = 1
+++

## Prerequisites

- [Crystal](https://crystal-lang.org/) >= 1.11.2

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  purl:
    github: hahwul/purl.cr
```

Run `shards install` to fetch the library.

## Your First Package URL

```crystal
require "purl"

# Parse an existing purl string
purl = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
puts purl.type      # => "npm"
puts purl.namespace  # => "@angular"
puts purl.name       # => "animation"
puts purl.version    # => "12.3.1"
```

## Creating a Package URL

You can also construct a Package URL from its components:

```crystal
require "purl"

purl = Purl::PackageURL.new(
  type: "maven",
  namespace: "org.apache.commons",
  name: "commons-lang3",
  version: "3.12.0"
)

puts purl.to_s
# => "pkg:maven/org.apache.commons/commons-lang3@3.12.0"
```

## What is a Package URL?

A Package URL (purl) is a URL string used to identify and locate a software package in a mostly universal and uniform way across programming languages, package managers, packaging conventions, tools, APIs and databases.

The format is:

```
pkg:type/namespace/name@version?qualifiers#subpath
```

| Component    | Required | Description |
|-------------|----------|-------------|
| `type`      | Yes      | The package type or protocol (e.g., `npm`, `pypi`, `maven`) |
| `namespace` | No       | Type-specific package prefix (e.g., npm scope, Maven groupId) |
| `name`      | Yes      | The name of the package |
| `version`   | No       | The version of the package |
| `qualifiers`| No       | Extra qualifying data as key-value pairs |
| `subpath`   | No       | Extra subpath within a package |

## Next Steps

- **[Basic Usage](/user-guide/basic-usage/)** -- Learn about all the features
- **[Parsing](/user-guide/parsing/)** -- Details on parsing purl strings
- **[Type Normalization](/user-guide/type-normalization/)** -- How types are normalized
