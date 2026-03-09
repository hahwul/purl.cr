# purl.cr

A Crystal implementation of the [Package URL (purl) specification](https://github.com/package-url/purl-spec).

## Installation

Add this to your `shard.yml`:

```yaml
dependencies:
  purl:
    github: hahwul/purl.cr
```

Then run `shards install`.

## Usage

```crystal
require "purl"

# Create a PackageURL
purl = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
puts purl.to_s # => "pkg:npm/%40babel/core@7.20.0"

# Parse a purl string
purl = Purl::PackageURL.parse("pkg:maven/org.apache.commons/commons-lang3@3.12.0")
puts purl.type      # => "maven"
puts purl.namespace # => "org.apache.commons"
puts purl.name      # => "commons-lang3"
puts purl.version   # => "3.12.0"

# With qualifiers
purl = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3-1",
  qualifiers: {"arch" => "amd64", "distro" => "jessie"}
)
puts purl.to_s # => "pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie"
```

## Contributing

1. Fork it (<https://github.com/hahwul/purl.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT