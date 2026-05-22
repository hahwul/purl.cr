require "uri"

module Purl
  # Parses Package URL strings following the right-to-left algorithm
  # specified by the purl spec (ECMA-427).
  module Parser
    # Valid qualifier key pattern: starts with lowercase letter, contains only [a-z0-9._\-]
    QUALIFIER_KEY_PATTERN = /^[a-z][a-z0-9._\-]*$/

    # Parses a Package URL string and returns a PackageURL instance.
    def self.parse(purl_string : String) : PackageURL
      remainder = purl_string.strip
      raise Purl::Error.new("Invalid Package URL: empty string") if remainder.empty?

      # Step 1: Split off the subpath from the right side using `#`
      subpath : String? = nil
      if idx = remainder.rindex('#')
        subpath_raw = remainder[(idx + 1)..]
        remainder = remainder[...idx]
        subpath = Normalizer.decode_and_normalize_subpath(subpath_raw)
      end

      # Step 2: Split off the qualifiers from the right side using `?`
      qualifiers : Hash(String, String)? = nil
      if idx = remainder.rindex('?')
        qualifiers_raw = remainder[(idx + 1)..]
        remainder = remainder[...idx]
        qualifiers = parse_qualifiers(qualifiers_raw)
      end

      # Step 3: Split off scheme from left side using `:` - must be `pkg`
      idx = remainder.index(':')
      raise Purl::Error.new("Invalid Package URL: missing 'pkg:' scheme") unless idx
      scheme = remainder[...idx]
      remainder = remainder[(idx + 1)..]

      unless scheme.downcase == PackageURL::SCHEME
        raise Purl::Error.new("Invalid Package URL: scheme must be 'pkg', got '#{scheme}'")
      end

      # Remove leading slashes (e.g., "pkg://type/..." → "type/...")
      remainder = remainder.lstrip('/')

      # Step 4: Split off type from left side using first `/`
      idx = remainder.index('/')
      raise Purl::Error.new("Invalid Package URL: missing type or name") unless idx
      type = remainder[...idx].downcase
      remainder = remainder[(idx + 1)..]

      # Step 5: Split off version from right side using `@`
      version : String? = nil
      if idx = remainder.rindex('@')
        version = Encoder.decode_segment(remainder[(idx + 1)..])
        remainder = remainder[...idx]
      end

      # Step 6: Split off name from right side using last `/`. Each segment
      # is decoded via Encoder.decode_segment so an encoded slash (%2F)
      # inside a single segment is preserved instead of being conflated
      # with the structural separator (purl spec ECMA-427).
      name : String
      namespace : String? = nil

      if idx = remainder.rindex('/')
        name = Encoder.decode_segment(remainder[(idx + 1)..])
        namespace_raw = remainder[...idx]
        namespace = namespace_raw.split("/").map { |seg| Encoder.decode_segment(seg) }.join("/")
        namespace = nil if namespace.strip.empty?
      else
        name = Encoder.decode_segment(remainder)
      end

      raise Purl::Error.new("Invalid Package URL: name must not be empty") if name.strip.empty?

      PackageURL.new(type, namespace, name, version, qualifiers, subpath)
    end

    # Parses qualifier query string into a hash of key-value pairs.
    def self.parse_qualifiers(raw : String) : Hash(String, String)?
      return if raw.strip.empty?
      result = Hash(String, String).new
      raw.split("&").each do |pair|
        next if pair.empty?
        key, _, value = pair.partition("=")
        key = key.downcase
        next if value.strip.empty?
        # Per spec, qualifier keys are unencoded ASCII identifiers — reject
        # anything that doesn't match the canonical form so two different
        # encodings of the same key cannot survive into the parsed result.
        unless QUALIFIER_KEY_PATTERN.matches?(key)
          raise Purl::Error.new("Invalid qualifier key '#{key}': must start with a letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
        end
        decoded_value = URI.decode(value)
        result[key] = decoded_value
      end
      result.empty? ? nil : result
    end
  end
end
