module Purl
  # Per-type component rules taken from the official purl type definitions
  # (https://github.com/package-url/purl-spec/tree/main/types). Every
  # `<type>-definition.json` declares whether each component is `required`,
  # `optional` or `prohibited`, and may pin the characters a component
  # accepts or the qualifier keys it demands.
  #
  # ECMA-427 defers to those definitions: the namespace "is optional, unless
  # required by the package's type definition", and a name or version "may
  # contain any Unicode character unless the package's type definition
  # further restricts the allowed characters". A purl that violates its own
  # type definition is therefore not a valid purl.
  module TypeRules
    # Types whose `namespace_definition.requirement` is "required".
    REQUIRED_NAMESPACE_TYPES = %w[
      alpm apk bitbucket composer deb git github golang huggingface maven
      qpkg rpm swift vscode-extension
    ]

    # Types whose `namespace_definition.requirement` is "prohibited".
    PROHIBITED_NAMESPACE_TYPES = %w[
      bazel bitnami cargo chrome-extension cocoapods conda cran gem hackage
      julia mlflow nuget oci opam otp pub pypi vcpkg
    ]

    # Types whose name is the path to a repository rather than a single
    # segment, so a slash inside it is a real path separator and stays
    # unencoded: `pkg:git/codeberg.org/forgejo/forgejo` names the repository
    # "forgejo/forgejo" on the host "codeberg.org". Every other type packs a
    # name into one segment, where a slash has to be percent-encoded.
    SLASHED_NAME_TYPES = %w[git]

    # `name_definition.permitted_characters` for the types that pin one.
    NAME_PATTERNS = {
      # A Chrome Web Store extension ID is exactly 32 letters from a to p.
      "chrome-extension" => /\A[a-p]{32}\z/,
    }

    # `version_definition.permitted_characters` for the types that pin one.
    VERSION_PATTERNS = {
      # A Chrome extension version is one to four dot-separated numbers.
      "chrome-extension" => /\A\d+(\.\d+){0,3}\z/,
    }

    # Qualifier keys whose definition marks them `requirement: "required"`.
    REQUIRED_QUALIFIER_KEYS = {
      "julia" => %w[uuid],
      "swid"  => %w[tag_id],
    }

    # A cpan name is a distribution name ("URI-PackageURL"), never a module
    # name ("URI::PackageURL"); the definition states that a distribution
    # name "shall not contain the string '::'".
    MODULE_SEPARATOR = "::"

    # Raises `Purl::Error` when the already-normalized components violate the
    # purl type definition for `type`.
    def self.validate(
      type : String,
      namespace : String?,
      name : String,
      version : String?,
      qualifiers : Hash(String, String)?,
    ) : Nil
      validate_namespace(type, namespace)
      validate_pattern(NAME_PATTERNS[type]?, type, "name", name)
      validate_pattern(VERSION_PATTERNS[type]?, type, "version", version)
      validate_required_qualifiers(type, qualifiers)

      if type == "cpan" && name.includes?(MODULE_SEPARATOR)
        raise Purl::Error.new("Invalid name '#{name}' for type 'cpan': the name is a distribution name, which must not contain '::'")
      end
    end

    private def self.validate_namespace(type : String, namespace : String?) : Nil
      if namespace.nil? && type.in?(REQUIRED_NAMESPACE_TYPES)
        raise Purl::Error.new("Invalid Package URL: type '#{type}' requires a namespace")
      end

      if namespace && type.in?(PROHIBITED_NAMESPACE_TYPES)
        raise Purl::Error.new("Invalid Package URL: type '#{type}' does not allow a namespace, got '#{namespace}'")
      end

      # For a slashed-name type the namespace is just the host, so it is a
      # single segment and every later segment belongs to the name. A
      # multi-segment namespace has no canonical form: `pkg:git/a/b/c` always
      # parses back as the namespace "a" and the name "b/c".
      if namespace && namespace.includes?('/') && type.in?(SLASHED_NAME_TYPES)
        raise Purl::Error.new("Invalid Package URL: type '#{type}' namespace is the host and must be a single segment, got '#{namespace}'")
      end
    end

    private def self.validate_pattern(pattern : Regex?, type : String, component : String, value : String?) : Nil
      return unless pattern && value
      return if pattern.matches?(value)
      raise Purl::Error.new("Invalid #{component} '#{value}' for type '#{type}': must match #{pattern.source}")
    end

    private def self.validate_required_qualifiers(type : String, qualifiers : Hash(String, String)?) : Nil
      keys = REQUIRED_QUALIFIER_KEYS[type]?
      return unless keys

      keys.each do |key|
        next if qualifiers && qualifiers.has_key?(key)
        raise Purl::Error.new("Invalid Package URL: type '#{type}' requires the '#{key}' qualifier")
      end
    end
  end
end
