require "../src/purl"

# =============================================================================
# Parsing Example
# =============================================================================
# Demonstrates parsing Package URL strings with purl.cr

purl_strings = [
  "pkg:npm/%40angular/animation@12.3.1",
  "pkg:pypi/django@4.2.0",
  "pkg:maven/org.apache.commons/commons-lang3@3.12.0",
  "pkg:gem/rails@7.0.0",
  "pkg:github/hahwul/purl.cr@v0.2.0",
  "pkg:deb/debian/curl@7.50.3-1?arch=amd64&distro=jessie",
  "pkg:golang/github.com/gorilla/mux@v1.8.0",
  "pkg:cargo/serde@1.0.0",
  "pkg:nuget/Newtonsoft.Json@13.0.1",
  "pkg:docker/library/nginx@1.25.0",
]

purl_strings.each do |str|
  purl = Purl::PackageURL.parse(str)
  puts "Input:      #{str}"
  puts "  Type:       #{purl.type}"
  puts "  Namespace:  #{purl.namespace || "(none)"}"
  puts "  Name:       #{purl.name}"
  puts "  Version:    #{purl.version || "(none)"}"
  if quals = purl.qualifiers
    puts "  Qualifiers: #{quals}"
  end
  puts "  Roundtrip:  #{purl}"
  puts ""
end

# --- Error handling ---

puts "--- Error Handling ---"
invalid_inputs = [
  "",
  "not-a-purl",
  "http:npm/express",
  "pkg:npm/",
]

invalid_inputs.each do |input|
  Purl::PackageURL.parse(input)
  puts "#{input.inspect} => (unexpectedly valid)"
rescue ex : Purl::Error
  puts "#{input.inspect} => Error: #{ex.message}"
end
