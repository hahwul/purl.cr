+++
title = "Type Normalization"
description = "Type-specific normalization rules"
weight = 4
+++

## Overview

The purl specification defines type-specific normalization rules for certain package ecosystems. purl.cr automatically applies these rules when creating or parsing Package URLs.

## Type is Always Lowercased

Regardless of the input, the `type` component is always converted to lowercase:

```crystal
purl = Purl::PackageURL.new("NPM", nil, "express")
purl.type  # => "npm"
```

## Normalization Rules by Type

### pypi

- Name is **lowercased** and each run of `-`, `_` and `.` is replaced with a single hyphen (PEP 503)

```crystal
purl = Purl::PackageURL.new("pypi", nil, "Django_Rest_Framework")
purl.name  # => "django-rest-framework"

Purl::PackageURL.new("pypi", nil, "zope.interface").name  # => "zope-interface"
```

### golang

- Name and namespace are **lowercased**

```crystal
purl = Purl::PackageURL.new("golang", "GitHub.com/User", "Repo")
purl.namespace  # => "github.com/user"
purl.name       # => "repo"
```

### deb

- Name and namespace are **lowercased**

```crystal
purl = Purl::PackageURL.new("deb", "Debian", "Curl")
purl.namespace  # => "debian"
purl.name       # => "curl"
```

### rpm

- Namespace is **lowercased**

```crystal
purl = Purl::PackageURL.new("rpm", "Fedora", "curl")
purl.namespace  # => "fedora"
```

### github / bitbucket

- Name and namespace are **lowercased**

```crystal
purl = Purl::PackageURL.new("github", "HahWul", "Purl.CR")
purl.namespace  # => "hahwul"
purl.name       # => "purl.cr"
```

### Other Types

Types not listed above (e.g., `npm`, `maven`, `gem`, `nuget`, `cargo`) preserve the original case for name and namespace:

```crystal
purl = Purl::PackageURL.new("maven", "org.Apache", "Commons")
purl.namespace  # => "org.Apache"
purl.name       # => "Commons"
```

## Qualifier Normalization

Qualifier keys are always lowercased and validated:

- Must start with a lowercase letter
- May contain lowercase letters, digits, `.`, `_`, or `-`
- Empty values are discarded

```crystal
purl = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3",
  qualifiers: {"Arch" => "amd64", "empty" => "  "}
)
purl.qualifiers  # => {"arch" => "amd64"} (key lowercased, empty removed)
```

## Subpath Normalization

Subpath segments are cleaned:

- Empty segments are removed
- `.` and `..` segments are discarded (not resolved against the previous segment)
- Leading/trailing slashes are removed
- `otp` subpaths are lowercased, because the otp type definition marks the subpath case insensitive

A subpath passed to the constructor is decoded text, like every other
component: it is not percent-decoded, and a literal `%` serializes as `%25`.
So a purl rebuilt from its own getters is the same purl.

```crystal
purl = Purl::PackageURL.new("npm", nil, "pkg", subpath: "50%25/foo%2Fbar")
purl.subpath  # => "50%25/foo%2Fbar"
purl.to_s     # => "pkg:npm/pkg#50%2525/foo%252Fbar"
```

```crystal
purl = Purl::PackageURL.new(
  "github", "user", "repo", nil,
  subpath: "./src/../lib/"
)
purl.subpath  # => "src/lib"
```
