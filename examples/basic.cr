require "../src/purl"

# =============================================================================
# Basic Usage Example
# =============================================================================
# Demonstrates creating and using Package URLs with purl.cr

# --- Creating Package URLs from components ---

# Simple package (type + name only)
purl = Purl::PackageURL.new("gem", nil, "rails")
puts "Simple:     #{purl.to_s}"
# => pkg:gem/rails

# With namespace and version
purl = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
puts "NPM:        #{purl.to_s}"
# => pkg:npm/%40babel/core@7.20.0

# Maven package with namespace
purl = Purl::PackageURL.new("maven", "org.apache.commons", "commons-lang3", "3.12.0")
puts "Maven:      #{purl.to_s}"
# => pkg:maven/org.apache.commons/commons-lang3@3.12.0

# PyPI package (name is auto-normalized)
purl = Purl::PackageURL.new("pypi", nil, "Django_Rest_Framework", "3.14.0")
puts "PyPI:       #{purl.to_s}"
# => pkg:pypi/django-rest-framework@3.14.0

# With qualifiers
purl = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3-1",
  qualifiers: {"arch" => "amd64", "distro" => "jessie"}
)
puts "Deb:        #{purl.to_s}"
# => pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie

# With subpath
purl = Purl::PackageURL.new(
  "github", "hahwul", "purl.cr", "v0.2.0",
  subpath: "src/purl.cr"
)
puts "GitHub:     #{purl.to_s}"
# => pkg:github/hahwul/purl.cr@v0.2.0#src/purl.cr

# --- Accessing components ---

puts "\n--- Component Access ---"
purl = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1")
puts "Type:       #{purl.type}"
puts "Namespace:  #{purl.namespace}"
puts "Name:       #{purl.name}"
puts "Version:    #{purl.version}"
puts "Qualifiers: #{purl.qualifiers}"
puts "Subpath:    #{purl.subpath}"

# --- Equality ---

puts "\n--- Equality ---"
a = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
b = Purl::PackageURL.new("npm", "@babel", "core", "7.20.0")
puts "Equal: #{a == b}" # => true
