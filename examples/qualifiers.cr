require "../src/purl"

# =============================================================================
# Qualifiers Example
# =============================================================================
# Demonstrates working with Package URL qualifiers

# --- Creating purls with qualifiers ---

# Debian package with architecture and distro
deb = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3-1",
  qualifiers: {
    "arch"   => "amd64",
    "distro" => "jessie",
  }
)
puts "Deb purl: #{deb}"
# => pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie

# Docker image with tag and repository
docker = Purl::PackageURL.new(
  "docker", "library", "nginx", "1.25.0",
  qualifiers: {
    "repository_url" => "docker.io",
    "tag"            => "latest",
  }
)
puts "Docker purl: #{docker}"

# Maven with classifier
maven = Purl::PackageURL.new(
  "maven", "org.apache", "commons-lang3", "3.12.0",
  qualifiers: {
    "packaging"  => "jar",
    "classifier" => "sources",
  }
)
puts "Maven purl: #{maven}"

# --- Accessing qualifiers ---

puts "\n--- Accessing Qualifiers ---"
purl = Purl::PackageURL.parse("pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie")

if quals = purl.qualifiers
  puts "All qualifiers: #{quals}"
  puts "arch: #{quals["arch"]}"
  puts "distro: #{quals["distro"]}"
end

# --- Creating a new purl with different qualifiers ---

puts "\n--- Creating with Qualifiers ---"
purl = Purl::PackageURL.new("npm", nil, "express", "4.18.0")
puts "Without: #{purl}"

purl_with_quals = Purl::PackageURL.new("npm", nil, "express", "4.18.0",
  qualifiers: {"engine" => "node", "runtime" => "v18"})
puts "With:    #{purl_with_quals}"

# --- Qualifier key normalization ---

puts "\n--- Key Normalization ---"
# Keys are automatically lowercased, empty values are discarded
purl = Purl::PackageURL.new(
  "npm", nil, "express", "4.18.0",
  qualifiers: {
    "Arch"    => "x64",
    "empty"   => "  ",
    "OS_Type" => "linux",
  }
)
puts "Normalized: #{purl}"
puts "Qualifiers: #{purl.qualifiers}"
# Keys lowercased, "empty" removed due to whitespace-only value

# --- Qualifiers are sorted alphabetically in output ---

puts "\n--- Alphabetical Sorting ---"
purl = Purl::PackageURL.new(
  "deb", "debian", "curl", "7.50.3",
  qualifiers: {
    "distro" => "jessie",
    "arch"   => "amd64",
  }
)
puts purl.to_s
# => pkg:deb/debian/curl@7.50.3?arch=amd64&distro=jessie (arch before distro)
