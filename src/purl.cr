# A Crystal implementation of the Package URL (purl) specification.
# See: https://github.com/package-url/purl-spec
# Spec: ECMA-427
require "uri"

module Purl
  VERSION = "0.2.0"

  class Error < Exception; end

  # Represents a Package URL as defined by the purl specification (ECMA-427).
  #
  # A Package URL is a URL string used to identify and locate a software package
  # in a mostly universal and uniform way across programming languages.
  #
  # Format: pkg:type/namespace/name@version?qualifiers#subpath
  #
  # Example:
  # ```
  # purl = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1")
  # purl.to_s # => "pkg:npm/%40angular/animation@12.3.1"
  # ```
  class PackageURL
    SCHEME = "pkg"

    # Valid type pattern: starts with letter, contains only [a-zA-Z0-9.+\-]
    TYPE_PATTERN = /^[a-zA-Z][a-zA-Z0-9.+\-]*$/

    # Valid qualifier key pattern: starts with lowercase letter, contains only [a-z0-9._\-]
    QUALIFIER_KEY_PATTERN = /^[a-z][a-z0-9._\-]*$/

    # Characters that should NOT be percent-encoded in qualifier values
    # Per spec: qualifier values are percent-encoded strings, but `:` and `/` should not be encoded
    QUALIFIER_VALUE_SAFE = ":/@"

    property type : String
    property namespace : String?
    property name : String
    property version : String?
    property qualifiers : Hash(String, String)?
    property subpath : String?

    def initialize(
      type : String,
      namespace : String?,
      name : String,
      version : String? = nil,
      qualifiers : Hash(String, String)? = nil,
      subpath : String? = nil,
    )
      # Normalize type to lowercase
      @type = type.downcase

      # Validate type
      raise Purl::Error.new("Invalid type: type must not be empty") if @type.empty?
      unless TYPE_PATTERN.matches?(@type)
        raise Purl::Error.new("Invalid type '#{@type}': must start with a letter and contain only ASCII letters, digits, '.', '+' or '-'")
      end

      # Validate name
      raise Purl::Error.new("Invalid name: name must not be empty") if name.strip.empty?

      # Normalize namespace
      ns = namespace
      if ns && ns.strip.empty?
        ns = nil
      end
      @namespace = ns ? normalize_namespace(@type, ns) : nil

      # Normalize name per type
      @name = normalize_name(@type, name)

      # Version stored as-is (already decoded if from parser)
      @version = version

      # Normalize qualifiers
      if qualifiers
        normalized = Hash(String, String).new
        qualifiers.each do |key, value|
          k = key.downcase
          next if value.strip.empty?
          unless QUALIFIER_KEY_PATTERN.matches?(k)
            raise Purl::Error.new("Invalid qualifier key '#{k}': must start with a letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
          end
          normalized[k] = value
        end
        @qualifiers = normalized.empty? ? nil : normalized
      else
        @qualifiers = nil
      end

      # Normalize subpath
      @subpath = subpath ? normalize_subpath(subpath) : nil
    end

    # Returns the Package URL as a string in the purl format.
    def to_s : String
      String.build do |str|
        str << SCHEME << ":" << @type

        if ns = @namespace
          str << "/"
          # Split namespace by `/` and encode each segment individually
          segments = ns.split("/")
          segments.each_with_index do |seg, i|
            str << "/" if i > 0
            str << encode_component(seg)
          end
        end

        str << "/" << encode_component(@name)

        if ver = @version
          str << "@" << encode_component(ver)
        end

        if quals = @qualifiers
          str << "?"
          # Sort by key alphabetically
          sorted_keys = quals.keys.sort
          sorted_keys.each_with_index do |key, i|
            str << "&" if i > 0
            str << key << "=" << encode_qualifier_value(quals[key])
          end
        end

        if sub = @subpath
          str << "#"
          # Split subpath and encode each segment
          segments = sub.split("/")
          segments.each_with_index do |seg, i|
            str << "/" if i > 0
            str << encode_component(seg)
          end
        end
      end
    end

    def to_s(io : IO) : Nil
      io << to_s
    end

    # Equality comparison: two PackageURLs are equal if all normalized components match.
    def ==(other : PackageURL) : Bool
      @type == other.type &&
        @namespace == other.namespace &&
        @name == other.name &&
        @version == other.version &&
        @qualifiers == other.qualifiers &&
        @subpath == other.subpath
    end

    def hash(hasher)
      hasher = @type.hash(hasher)
      hasher = @namespace.hash(hasher)
      hasher = @name.hash(hasher)
      hasher = @version.hash(hasher)
      hasher = @qualifiers.hash(hasher)
      hasher = @subpath.hash(hasher)
      hasher
    end

    # Parses a Package URL string and returns a PackageURL instance.
    #
    # Follows the right-to-left parsing algorithm specified by the purl spec.
    # Raises `Purl::Error` if the string is not a valid Package URL.
    def self.parse(purl_string : String) : PackageURL
      remainder = purl_string.strip

      raise Purl::Error.new("Invalid Package URL: empty string") if remainder.empty?

      # Step 1: Split off the subpath from the right side using `#`
      subpath : String? = nil
      if idx = remainder.rindex('#')
        subpath_raw = remainder[(idx + 1)..]
        remainder = remainder[...idx]
        subpath = decode_and_normalize_subpath(subpath_raw)
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

      unless scheme.downcase == SCHEME
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
        version = URI.decode(remainder[(idx + 1)..])
        remainder = remainder[...idx]
      end

      # Step 6: Split off name from right side using last `/`
      name : String
      namespace : String? = nil

      if idx = remainder.rindex('/')
        name = URI.decode(remainder[(idx + 1)..])
        namespace_raw = remainder[...idx]
        # Decode each namespace segment individually
        namespace = namespace_raw.split("/").map { |seg| URI.decode(seg) }.join("/")
        namespace = nil if namespace.strip.empty?
      else
        name = URI.decode(remainder)
      end

      raise Purl::Error.new("Invalid Package URL: name must not be empty") if name.strip.empty?

      PackageURL.new(type, namespace, name, version, qualifiers, subpath)
    end

    # --- Private helpers ---

    private def normalize_name(type : String, name : String) : String
      case type
      when "pypi"
        name.gsub('_', '-').downcase
      when "npm", "golang", "deb", "github", "bitbucket"
        name.downcase
      else
        name
      end
    end

    private def normalize_namespace(type : String, namespace : String) : String
      case type
      when "npm", "golang", "deb", "rpm", "github", "bitbucket"
        namespace.downcase
      else
        namespace
      end
    end

    private def normalize_subpath(subpath : String) : String?
      segments = subpath.split("/").reject { |s| s.empty? || s == "." || s == ".." }
      return nil if segments.empty?
      segments.join("/")
    end

    private def self.decode_and_normalize_subpath(raw : String) : String?
      segments = raw.split("/")
        .map { |s| URI.decode(s) }
        .reject { |s| s.empty? || s == "." || s == ".." }
      return nil if segments.empty?
      segments.join("/")
    end

    private def self.parse_qualifiers(raw : String) : Hash(String, String)?
      return nil if raw.strip.empty?
      result = Hash(String, String).new
      raw.split("&").each do |pair|
        next if pair.empty?
        key, _, value = pair.partition("=")
        key = key.downcase
        next if value.strip.empty?
        decoded_value = URI.decode(value)
        result[key] = decoded_value
      end
      result.empty? ? nil : result
    end

    # Percent-encode a purl component (namespace segment, name, version).
    # Encodes all characters except unreserved characters (RFC 3986).
    private def encode_component(value : String) : String
      URI.encode_path_segment(value)
    end

    # Encode qualifier value: similar to encode_component but preserves `:` and `/`
    private def encode_qualifier_value(value : String) : String
      String.build do |str|
        value.each_char do |c|
          if c == ':' || c == '/'
            str << c
          elsif c.ascii_alphanumeric? || c == '-' || c == '.' || c == '_' || c == '~'
            str << c
          else
            c.to_s.to_slice.each do |byte|
              str << '%'
              str << byte.to_s(16, upcase: true).rjust(2, '0')
            end
          end
        end
      end
    end
  end
end
