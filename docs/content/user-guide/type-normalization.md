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

### npm

- Name and namespace are **lowercased**

```crystal
purl = Purl::PackageURL.new("npm", "@Angular", "Core")
purl.namespace  # => "@angular"
purl.name       # => "core"
```

### pypi

- Name is **lowercased** and **underscores are replaced with hyphens**

```crystal
purl = Purl::PackageURL.new("pypi", nil, "Django_Rest_Framework")
purl.name  # => "django-rest-framework"
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

Types not listed above (e.g., `maven`, `gem`, `nuget`, `cargo`) preserve the original case for name and namespace:

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
- `.` and `..` segments are stripped
- Leading/trailing slashes are removed

```crystal
purl = Purl::PackageURL.new(
  "github", "user", "repo", nil,
  subpath: "./src/../src/lib/"
)
purl.subpath  # => "src/lib"
```
