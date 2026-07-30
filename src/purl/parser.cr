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
      # The raw (still percent-encoded) subpath is handed to PackageURL, which
      # decodes and normalizes it exactly once. Decoding it here as well would
      # decode it twice: `#foo%252Fbar` would become "foo%2Fbar" and then
      # "foo/bar", turning one literal segment into two.
      if idx = remainder.rindex('#')
        subpath = remainder[(idx + 1)..]
        remainder = remainder[...idx]
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

      # Step 5: Split off version from right side using `@`.
      #
      # The version is a single opaque component, not a `/`-separated path, so
      # an encoded slash carries no structural meaning there: `%2F` and a raw
      # `/` denote the same character. It is therefore fully decoded (unlike
      # namespace/name segments, where `%2F` must stay distinct from the
      # segment separator). Decoding it as a segment would keep the literal
      # "%2F" marker in the value and break round-tripping, because the
      # encoder re-emits the marker verbatim: `pkg:npm/a@1/2` would parse to
      # version "1/2", serialize to "1%2F2", and re-parse to "1%2F2".
      version : String? = nil
      if idx = version_separator_index(remainder)
        version = URI.decode(remainder[(idx + 1)..])
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

    # Locates the `@` that separates the version.
    #
    # The version always trails the name, so the separator can only live in
    # the last path segment. Taking the rightmost `@` anywhere in the
    # remainder misreads an unencoded npm scope — `pkg:npm/@babel/core` has to
    # parse as namespace "@babel" / name "core", not as an empty name with the
    # version "babel/core". Confining the search to the final segment also
    # keeps genuinely nameless purls invalid, since `pkg:cran/@0.9.1` still
    # splits into an empty name and the version "0.9.1".
    private def self.version_separator_index(remainder : String) : Int32?
      segment_start = (slash = remainder.rindex('/')) ? slash + 1 : 0
      idx = remainder.rindex('@')
      idx && idx >= segment_start ? idx : nil
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
        # ECMA-427: "Each key shall be unique among all the keys of the
        # qualifiers component." Silently keeping the last occurrence would
        # discard data from an invalid purl without telling the caller —
        # `?arch=amd64&arch=i386` would resolve to a single arch.
        if result.has_key?(key)
          raise Purl::Error.new("Duplicate qualifier key '#{key}': each key must appear at most once")
        end
        result[key] = URI.decode(value)
      end
      result.empty? ? nil : result
    end
  end
end
