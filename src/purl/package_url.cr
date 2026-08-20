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

    # Valid type pattern: starts with letter, contains only [a-zA-Z0-9.\-].
    # ECMA-427: the type "shall be composed only of ASCII letters and numbers,
    # period '.', and dash '-'" and "shall start with an ASCII letter".
    TYPE_PATTERN = /^[a-zA-Z][a-zA-Z0-9.\-]*$/

    # Valid qualifier key pattern: starts with lowercase letter, contains only [a-z0-9._\-]
    QUALIFIER_KEY_PATTERN = /^[a-z][a-z0-9._\-]*$/

    getter type : String
    getter namespace : String?
    getter name : String
    getter version : String?
    getter subpath : String?

    @qualifiers : Hash(String, String)?

    # The normalized qualifiers, or nil when there are none.
    #
    # Returns a copy. A PackageURL is a value object whose `==` and `#hash`
    # are derived from its qualifiers, so handing out the internal hash would
    # let a caller mutate a purl that is already in use as a Hash key and
    # quietly break every lookup for it. Build a new PackageURL from a
    # modified copy instead of mutating this one.
    def qualifiers : Hash(String, String)?
      @qualifiers.try(&.dup)
    end

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
        raise Purl::Error.new("Invalid type '#{@type}': must start with a letter and contain only ASCII letters, digits, '.' or '-'")
      end

      raise Purl::Error.new("Invalid name: name must not be empty") if name.strip.empty?

      ns = namespace
      if ns && ns.strip.empty?
        ns = nil
      end

      # A blank version carries no information and is not part of the
      # canonical form: `pkg:npm/foo@` and `pkg:npm/foo` denote the same
      # package, so an empty (or whitespace-only) version collapses to nil
      # rather than being serialized back as a dangling `@`.
      ver = version
      if ver && ver.strip.empty?
        ver = nil
      end

      @namespace = ns ? normalize_optional_namespace(@type, ns) : nil
      @version = ver ? Normalizer.normalize_version(@type, ver) : nil
      # The qualifiers are normalized before the name because a few types
      # (mlflow) derive the name's case from the `repository_url` qualifier.
      @qualifiers = normalize_qualifiers(qualifiers)
      @name = Normalizer.normalize_name_for_qualifiers(
        @type, Normalizer.normalize_name(@type, name), @qualifiers)
      @subpath = subpath ? Normalizer.normalize_subpath(subpath) : nil

      raise Purl::Error.new("Invalid name: name must not be empty") if @name.empty?

      TypeRules.validate(@type, @namespace, @name, @version, @qualifiers)
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

      # A `git` name is a repository path whose slashes are separators, so
      # each of its segments is encoded on its own; every other type's name
      # is a single segment where a slash is percent-encoded.
      io << "/"
      @name.split("/").each_with_index do |seg, i|
        io << "/" if i > 0
        io << Encoder.encode_component(seg)
      end

      if ver = @version
        io << "@" << Encoder.encode_literal(ver)
      end

      if quals = @qualifiers
        io << "?"
        quals.keys.sort!.each_with_index do |key, i|
          io << "&" if i > 0
          io << key << "=" << Encoder.encode_qualifier_value(quals[key])
        end
      end

      if sub = @subpath
        io << "#"
        sub.split("/").each_with_index do |seg, i|
          io << "/" if i > 0
          io << Encoder.encode_literal(seg)
        end
      end
    end

    # Equality comparison: two PackageURLs are equal if all normalized components match.
    # Compares the qualifiers directly rather than through the getter, which
    # copies.
    def ==(other : PackageURL) : Bool
      @type == other.type &&
        @namespace == other.namespace &&
        @name == other.name &&
        @version == other.version &&
        @qualifiers == other.@qualifiers &&
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

    # Normalize a namespace and collapse it to nil if stripping empty path
    # segments (e.g. "//") leaves nothing meaningful behind.
    private def normalize_optional_namespace(type : String, namespace : String) : String?
      normalized = Normalizer.normalize_namespace(type, namespace)
      normalized.empty? ? nil : normalized
    end

    private def normalize_qualifiers(qualifiers : Hash(String, String)?) : Hash(String, String)?
      return unless qualifiers

      normalized = Hash(String, String).new
      qualifiers.each do |key, value|
        # The build algorithm joins "the lowercased key" with its value, so a
        # caller-supplied key is normalized here. A key parsed out of a purl
        # string is *rejected* instead, because ECMA-427 requires the key to
        # already be lowercase in a valid purl — see `Parser.parse_qualifiers`.
        k = key.downcase
        next if value.strip.empty?
        unless QUALIFIER_KEY_PATTERN.matches?(k)
          raise Purl::Error.new("Invalid qualifier key '#{k}': must start with a letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
        end
        # Keys are compared after downcasing, so distinct keys in the input
        # hash can collide here (e.g. "Arch" and "arch"). Report that rather
        # than letting one value silently overwrite the other.
        if normalized.has_key?(k)
          raise Purl::Error.new("Duplicate qualifier key '#{k}': each key must appear at most once")
        end
        normalized[k] = value
      end
      normalized.empty? ? nil : normalized
    end
  end
end
