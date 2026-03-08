# A Crystal implementation of the Package URL (purl) specification.
# See: https://github.com/package-url/purl-spec
# Spec: ECMA-427
require "uri"

require "./purl/error"
require "./purl/normalizer"
require "./purl/encoder"
require "./purl/parser"
require "./purl/package_url"

module Purl
  VERSION = "0.2.0"
end
