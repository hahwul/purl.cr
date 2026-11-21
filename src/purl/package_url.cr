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
    # Anchored with `\A`/`\z`: `$` would also accept a trailing newline.
    TYPE_PATTERN = /\A[a-zA-Z][a-zA-Z0-9.\-]*\z/

    # Valid qualifier key pattern: starts with lowercase letter, contains only [a-z0-9._\-]
    QUALIFIER_KEY_PATTERN = /\A[a-z][a-z0-9._\-]*\z/

    getter type : String
    getter namespace : String?
    getter name : String
    getter version : String?
    getter subpath : String?

    @qualifiers : Hash(String, String)?
    @comparison_qualifiers : Hash(String, String)?

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

    # Builds a PURL from decoded components. Percent signs are literal.
    # A slash separates segments in a namespace, subpath, or git repository
    # name. In other names, a slash within the name is data.
    def initialize(
      type : String,
      namespace : String?,
      name : String,
      version : String? = nil,
      qualifiers : Hash(String, String)? = nil,
      subpath : String? = nil,
    )
      # ECMA-427 5.4: a component string is UTF-8. Invalid bytes (e.g. a
      # percent-decoded `%FF`) would crash the regex-based normalization or be
      # silently re-encoded as U+FFFD, so the purl is rejected instead.
      components = [type, namespace, name, version, subpath]
      qualifiers.try &.each { |key, value| components << key << value }
      unless components.all? { |c| c.nil? || c.valid_encoding? }
        raise Purl::Error.new("Invalid Package URL: components must be valid UTF-8")
      end

      # ASCII-only folding: the type is ASCII by definition, and a Unicode
      # downcase would turn the KELVIN SIGN (U+212A) into a valid "k".
      @type = type.downcase(Unicode::CaseOptions::ASCII)

      raise Purl::Error.new("Invalid type: type must not be empty") if @type.empty?
      unless TYPE_PATTERN.matches?(@type)
        raise Purl::Error.new("Invalid type '#{@type}': must start with a letter and contain only ASCII letters, digits, '.' or '-'")
      end

      @namespace = namespace ? normalize_optional_namespace(@type, namespace) : nil
      @version = Normalizer.normalize_version(@type, version) if version && !version.empty?
      # The qualifiers are normalized before the name because a few types
      # (mlflow) derive the name's case from the `repository_url` qualifier.
      @qualifiers = normalize_qualifiers(qualifiers)
      @comparison_qualifiers = comparison_qualifiers(@qualifiers)
      @name = Normalizer.normalize_name_for_qualifiers(
        @type, Normalizer.normalize_name(@type, name), @qualifiers)
      @subpath = subpath ? Normalizer.normalize_subpath(@type, subpath) : nil

      raise Purl::Error.new("Invalid name: name must not be empty") if @name.empty?

      TypeRules.validate(@type, @namespace, @name, @version, @qualifiers, @subpath)
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
        write_path(io, "/", ns)
      end

      if @type.in?(TypeRules::SLASHED_NAME_TYPES)
        write_path(io, "/", @name)
      else
        io << "/" << Encoder.encode_literal(@name)
      end

      if ver = @version
        io << "@" << Encoder.encode_literal(ver)
      end

      if quals = @qualifiers
        io << "?"
        quals.keys.sort!.each_with_index do |key, i|
          io << "&" if i > 0
          io << key << "=" << Encoder.encode_literal(quals[key])
        end
      end

      if sub = @subpath
        write_path(io, "#", sub)
      end
    end

    private def write_path(io : IO, prefix : String, path : String) : Nil
      io << prefix
      path.split('/').each_with_index do |segment, index|
        io << "/" if index > 0
        io << Encoder.encode_literal(segment)
      end
    end

    # Compares the normalized components. SWID tag IDs compare without regard
    # to case, while their serialized form can preserve the original spelling.
    def ==(other : PackageURL) : Bool
      @type == other.type &&
        @namespace == other.namespace &&
        @name == other.name &&
        @version == other.version &&
        @comparison_qualifiers == other.@comparison_qualifiers &&
        @subpath == other.subpath
    end

    def hash(hasher)
      hasher = @type.hash(hasher)
      hasher = @namespace.hash(hasher)
      hasher = @name.hash(hasher)
      hasher = @version.hash(hasher)
      hasher = @comparison_qualifiers.hash(hasher)
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

    private def comparison_qualifiers(qualifiers : Hash(String, String)?) : Hash(String, String)?
      return qualifiers unless @type == "swid" && qualifiers
      return qualifiers unless tag_id = qualifiers["tag_id"]?

      folded_id = tag_id.downcase(Unicode::CaseOptions::Fold)
      folded_id == tag_id ? qualifiers : qualifiers.merge({"tag_id" => folded_id})
    end

    private def normalize_qualifiers(qualifiers : Hash(String, String)?) : Hash(String, String)?
      return unless qualifiers

      normalized = Hash(String, String).new
      qualifiers.each do |key, value|
        # The build algorithm joins "the lowercased key" with its value, so a
        # caller-supplied key is normalized here. A key parsed out of a purl
        # string is *rejected* instead, because ECMA-427 requires the key to
        # already be lowercase in a valid purl — see `Parser.parse_qualifiers`.
        k = key.downcase(Unicode::CaseOptions::ASCII)
        next if value.empty?
        unless QUALIFIER_KEY_PATTERN.matches?(k)
          raise Purl::Error.new("Invalid qualifier key '#{k}': must start with a letter and contain only lowercase ASCII letters, digits, '.', '_' or '-'")
        end
        # Keys are compared after downcasing, so distinct keys in the input
        # hash can collide here (e.g. "Arch" and "arch"). Report that rather
        # than letting one value silently overwrite the other.
        if normalized.has_key?(k)
          raise Purl::Error.new("Duplicate qualifier key '#{k}': each key must appear at most once")
        end
        normalized[k] = Normalizer.normalize_qualifier_value(@type, k, value)
      end
      normalized.empty? ? nil : normalized
    end
  end
end
