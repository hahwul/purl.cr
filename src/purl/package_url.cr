module Purl
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

    getter type : String
    getter namespace : String?
    getter name : String
    getter version : String?
    getter qualifiers : Hash(String, String)?
    getter subpath : String?

    def initialize(
      type : String,
      namespace : String?,
      name : String,
      version : String? = nil,
      qualifiers : Hash(String, String)? = nil,
      subpath : String? = nil,
    )
      @type = type.downcase

      raise Purl::Error.new("Invalid type: type must not be empty") if @type.empty?
      unless TYPE_PATTERN.matches?(@type)
        raise Purl::Error.new("Invalid type '#{@type}': must start with a letter and contain only ASCII letters, digits, '.', '+' or '-'")
      end

      raise Purl::Error.new("Invalid name: name must not be empty") if name.strip.empty?

      ns = namespace
      if ns && ns.strip.empty?
        ns = nil
      end
      @namespace = ns ? Normalizer.normalize_namespace(@type, ns) : nil
      @name = Normalizer.normalize_name(@type, name)
      @version = version
      @qualifiers = normalize_qualifiers(qualifiers)
      @subpath = subpath ? Normalizer.normalize_subpath(subpath) : nil
    end

    # Returns the Package URL as a string in the purl format.
    def to_s : String
      String.build do |io|
        to_s(io)
      end
    end

    # Writes the Package URL in purl format directly to the given IO.
    def to_s(io : IO) : Nil
      io << SCHEME << ":" << @type

      if ns = @namespace
        io << "/"
        ns.split("/").each_with_index do |seg, i|
          io << "/" if i > 0
          io << Encoder.encode_component(seg)
        end
      end

      io << "/" << Encoder.encode_component(@name)

      if ver = @version
        io << "@" << Encoder.encode_component(ver)
      end

      if quals = @qualifiers
        io << "?"
        quals.keys.sort.each_with_index do |key, i|
          io << "&" if i > 0
          io << key << "=" << Encoder.encode_qualifier_value(quals[key])
        end
      end

      if sub = @subpath
        io << "#"
        sub.split("/").each_with_index do |seg, i|
          io << "/" if i > 0
          io << Encoder.encode_component(seg)
        end
      end
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
    def self.parse(purl_string : String) : PackageURL
      Parser.parse(purl_string)
    end

    private def normalize_qualifiers(qualifiers : Hash(String, String)?) : Hash(String, String)?
      return nil unless qualifiers

      normalized = Hash(String, String).new
      qualifiers.each do |key, value|
        k = key.downcase
        next if value.strip.empty?
        unless QUALIFIER_KEY_PATTERN.matches?(k)
          raise Purl::Error.new("Invalid qualifier key '#{k}': must start with a letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
        end
        normalized[k] = value
      end
      normalized.empty? ? nil : normalized
    end
  end
end
