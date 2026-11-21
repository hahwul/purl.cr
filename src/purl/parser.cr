module Purl
  # Parses Package URL strings following the right-to-left algorithm
  # specified by the purl spec (ECMA-427).
  module Parser
    # Valid qualifier key pattern: starts with lowercase letter, contains only [a-z0-9._\-]
    QUALIFIER_KEY_PATTERN = PackageURL::QUALIFIER_KEY_PATTERN

    # Parses a Package URL string and returns a PackageURL instance.
    def self.parse(purl_string : String) : PackageURL
      # The parser runs regexes over raw pieces before PackageURL validates
      # the decoded components, and those raise ArgumentError on invalid UTF-8.
      raise Purl::Error.new("Invalid Package URL: not valid UTF-8") unless purl_string.valid_encoding?
      remainder = purl_string.strip
      raise Purl::Error.new("Invalid Package URL: empty string") if remainder.empty?

      # Step 1: Split off the subpath from the right side using `#`
      subpath : String? = nil
      if idx = remainder.rindex('#')
        subpath = decode_path(remainder[(idx + 1)..], "subpath")
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

      unless scheme.downcase(Unicode::CaseOptions::ASCII) == PackageURL::SCHEME
        raise Purl::Error.new("Invalid Package URL: scheme must be 'pkg', got '#{scheme}'")
      end

      # Remove leading slashes (e.g., "pkg://type/..." → "type/...")
      remainder = remainder.lstrip('/')

      # Step 4: Split off type from left side using first `/`
      idx = remainder.index('/')
      raise Purl::Error.new("Invalid Package URL: missing type or name") unless idx
      type = remainder[...idx].downcase(Unicode::CaseOptions::ASCII)
      remainder = remainder[(idx + 1)..]

      # Step 5: Split off the opaque version from the name.
      version : String? = nil
      if idx = version_separator_index(remainder)
        version = Encoder.decode(remainder[(idx + 1)..])
        remainder = remainder[...idx]
      else
        # how-to-parse strips "all trailing '/' characters" before splitting
        # off the name, and ECMA-427 5.6.4 says they "are not significant and
        # should be stripped", so `pkg:npm/foo/` names "foo", just as building
        # with the name "foo/" does. This only applies when no version
        # follows: a slash right before the `@` leaves no name at all, and
        # the conformance suite requires `pkg:swift/github.com/Alamofire/@5.4.3`
        # to fail.
        remainder = remainder.rstrip('/')
      end

      # A git namespace is the host and its name is the remaining repository
      # path. Other types split off a single name from the right.
      namespace : String? = nil
      if type.in?(TypeRules::SLASHED_NAME_TYPES)
        host, _, repository = remainder.partition('/')
        namespace = Encoder.decode_segment(host, "namespace")
        name = Encoder.decode(repository)
      elsif idx = remainder.rindex('/')
        namespace = decode_path(remainder[...idx], "namespace")
        name = Encoder.decode(remainder[(idx + 1)..])
      else
        name = Encoder.decode(remainder)
      end

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
      # Trailing slashes do not open a new segment: in `foo@1.0/` the `@`
      # still sits in the last one, as the right-to-left split finds it.
      segment_start = (slash = remainder.rstrip('/').rindex('/')) ? slash + 1 : 0
      idx = remainder.rindex('@')
      idx && idx >= segment_start ? idx : nil
    end

    private def self.decode_path(raw : String, component : String) : String
      raw.split('/').join('/') { |segment| Encoder.decode_segment(segment, component) }
    end

    # Parses qualifier query string into a hash of key-value pairs.
    def self.parse_qualifiers(raw : String) : Hash(String, String)?
      return if raw.empty?
      result = Hash(String, String).new
      raw.split("&").each do |pair|
        next if pair.empty?
        key, separator, value = pair.partition('=')
        if separator.empty?
          raise Purl::Error.new("Invalid qualifier '#{pair}': expected a key=value pair")
        end
        next if value.empty?
        # ECMA-427: "The key shall be composed only of lowercase ASCII letters
        # and numbers, period '.', dash '-' and underscore '_'" and "shall not
        # be percent-encoded". A key that is not already lowercase makes the
        # purl invalid, so it is rejected rather than quietly downcased: the
        # conformance suite requires `pkg:gem/jruby-launcher@1.1.2?Platform=java`
        # to fail. Callers building a purl from components still get their keys
        # normalized — see `PackageURL#normalize_qualifiers`.
        unless QUALIFIER_KEY_PATTERN.matches?(key)
          raise Purl::Error.new("Invalid qualifier key '#{key}': must start with a lowercase letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
        end
        # ECMA-427: "Each key shall be unique among all the keys of the
        # qualifiers component." Silently keeping the last occurrence would
        # discard data from an invalid purl without telling the caller —
        # `?arch=amd64&arch=i386` would resolve to a single arch.
        if result.has_key?(key)
          raise Purl::Error.new("Duplicate qualifier key '#{key}': each key must appear at most once")
        end
        result[key] = Encoder.decode(value)
      end
      result.empty? ? nil : result
    end
  end
end
