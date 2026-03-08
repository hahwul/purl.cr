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
puts "Deb purl: #{deb.to_s}"
# => pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie

# Docker image with tag and repository
docker = Purl::PackageURL.new(
  "docker", "library", "nginx", "1.25.0",
  qualifiers: {
    "repository_url" => "docker.io",
    "tag"            => "latest",
  }
)
puts "Docker purl: #{docker.to_s}"

# Maven with classifier
maven = Purl::PackageURL.new(
  "maven", "org.apache", "commons-lang3", "3.12.0",
  qualifiers: {
    "packaging"  => "jar",
    "classifier" => "sources",
  }
)
puts "Maven purl: #{maven.to_s}"

# --- Accessing qualifiers ---

puts "\n--- Accessing Qualifiers ---"
purl = Purl::PackageURL.parse("pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie")

if quals = purl.qualifiers
  puts "All qualifiers: #{quals}"
  puts "arch: #{quals["arch"]}"
  puts "distro: #{quals["distro"]}"
end

# --- Modifying qualifiers ---

puts "\n--- Modifying Qualifiers ---"
purl = Purl::PackageURL.new("npm", nil, "express", "4.18.0")
puts "Before: #{purl.to_s}"

purl.qualifiers = {"engine" => "node", "runtime" => "v18"}
puts "After:  #{purl.to_s}"

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
puts "Normalized: #{purl.to_s}"
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
