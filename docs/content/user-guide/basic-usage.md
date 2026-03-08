+++
title = "Basic Usage"
description = "Creating and manipulating Package URLs"
weight = 2
+++

## Creating Package URLs

The `Purl::PackageURL` constructor accepts all purl components:

```crystal
require "purl"

# Minimal: type and name only
purl = Purl::PackageURL.new("gem", nil, "rails")
puts purl.to_s  # => "pkg:gem/rails"

# With namespace and version
purl = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
puts purl.to_s  # => "pkg:npm/%40babel/core@7.20.0"

# With qualifiers
purl = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3-1",
  qualifiers: {"arch" => "amd64", "distro" => "jessie"}
)
puts purl.to_s
# => "pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie"

# With subpath
purl = Purl::PackageURL.new(
  "github", "hahwul", "purl.cr", "v0.2.0",
  subpath: "src/purl.cr"
)
puts purl.to_s
# => "pkg:github/hahwul/purl.cr@v0.2.0#src/purl.cr"
```

## Accessing Components

All components are available as properties:

```crystal
purl = Purl::PackageURL.parse("pkg:maven/org.apache/commons-lang3@3.12.0?packaging=jar")

purl.type       # => "maven"
purl.namespace  # => "org.apache"
purl.name       # => "commons-lang3"
purl.version    # => "3.12.0"
purl.qualifiers # => {"packaging" => "jar"}
purl.subpath    # => nil
```

## Modifying Components

Properties are mutable using Crystal's `property` syntax:

```crystal
purl = Purl::PackageURL.new("npm", nil, "express", "4.18.0")

purl.version = "4.19.0"
purl.qualifiers = {"engine" => "node"}

puts purl.to_s
# => "pkg:npm/express@4.19.0?engine=node"
```

## String Output

Call `to_s` to produce a valid, normalized purl string:

```crystal
purl = Purl::PackageURL.new("pypi", nil, "Django_Rest_Framework", "3.14.0")
puts purl.to_s
# => "pkg:pypi/django-rest-framework@3.14.0"
```

Note how the name is automatically normalized per PyPI conventions (underscores replaced with hyphens, lowercased).

## Equality

Two `PackageURL` instances are equal if all their normalized components match:

```crystal
a = Purl::PackageURL.parse("pkg:npm/%40babel/core@7.20.0")
b = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")

a == b  # => true
```
