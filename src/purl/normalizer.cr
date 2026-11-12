module Purl
  # Handles type-specific normalization of purl components.
  module Normalizer
    def self.normalize_name(type : String, name : String) : String
      # A `git` name is a repository path, so its slashes are real separators
      # and each segment is normalized on its own. Empty segments are dropped
      # for the same reason they are dropped from a namespace: the canonical
      # form has none.
      if type.in?(TypeRules::SLASHED_NAME_TYPES)
        segments = name.split("/").reject(&.strip.empty?).map do |seg|
          around_encoded_slash(seg) { |part| normalize_name_part(type, part) }
        end
        return segments.join("/")
      end

      # For every other type a name is a single path segment, so a raw "/" in
      # a caller-supplied name cannot be a separator — it can only be a slash
      # living *inside* the segment, which is exactly what the "%2F" marker
      # stands for. Converting it up front makes a constructed name match the
      # one you get back from parsing that purl, since the serialized form is
      # identical. Leading and trailing slashes are dropped first: ECMA-427
      # 5.6.4 says they "are not significant and should be stripped. They are
      # not part of the name", so "/foo/" names "foo", not "%2Ffoo%2F".
      around_encoded_slash(name.strip('/').gsub('/', "%2F")) { |part| normalize_name_part(type, part) }
    end

    def self.normalize_namespace(type : String, namespace : String) : String
      normalized = around_encoded_slash(namespace) { |part| normalize_namespace_part(type, part) }
      # The canonical purl form must not contain empty path segments, so a
      # namespace like "a//b" collapses to "a/b". Blank segments go the same
      # way: the parser discards a namespace that is only whitespace, so
      # keeping " " here would make a constructed purl differ from its own
      # parsed form (`pkg:npm/%20/pkg` parses back with no namespace at all).
      normalized.split("/").reject(&.strip.empty?).join("/")
    end

    # Apply a normalization rule to a namespace/name value without letting it
    # touch any embedded "%2F" marker. The marker is not part of the package
    # identity's text — it stands for a slash that was percent-encoded inside
    # a single segment — so rules must not see it: `downcase` would rewrite it
    # to a non-canonical "%2f", and pub's `[^a-z0-9_]` substitution would
    # mangle it into "_2f", silently changing which package the purl names.
    # Each chunk between markers is normalized separately and the pieces are
    # rejoined with the canonical "%2F".
    private def self.around_encoded_slash(value : String, & : String -> String) : String
      return yield value unless value.matches?(Encoder::ENCODED_SLASH)
      value.split(Encoder::ENCODED_SLASH).map { |part| yield part }.join("%2F")
    end

    # Types whose name is declared case-insensitive and must be lowercased.
    # These are the types whose definition sets `name_definition` to
    # `case_sensitive: false`, plus golang, whose definition keeps the flag
    # true but notes that "the name shall be lowercased".
    LOWERCASE_NAME_TYPES = %w[
      alpm apk bitbucket bitnami brew chrome-extension composer deb github
      golang hex luarocks oci otp vscode-extension
    ]

    # Types whose namespace is declared case-insensitive and must be
    # lowercased, again with golang added for its "shall be lowercased" note.
    LOWERCASE_NAMESPACE_TYPES = %w[
      alpm apk bitbucket brew composer deb github golang hex luarocks qpkg rpm
      vscode-extension yocto
    ]

    # Types whose version is declared case-insensitive and must be lowercased.
    LOWERCASE_VERSION_TYPES = %w[huggingface pypi vscode-extension]

    # Types whose namespace must be uppercased. `cpan` namespaces are CPAN
    # author IDs (CPANIDs), which the spec requires in uppercase.
    UPCASE_NAMESPACE_TYPES = %w[cpan]

    private def self.normalize_name_part(type : String, name : String) : String
      case type
      when "pypi"
        # The pypi definition: "The name shall be lowercase" and "Replace
        # runs of consecutive dash '-', underscore '_', or dot '.' characters
        # with a single dash '-'" (PEP 503 name normalization).
        name.downcase.gsub(/[-_.]+/, '-')
      when "pub"
        # pub names are lowercased and any char outside [a-z0-9_] becomes '_'.
        name.downcase.gsub(/[^a-z0-9_]/, '_')
      when .in?(LOWERCASE_NAME_TYPES)
        name.downcase
      else
        name
      end
    end

    private def self.normalize_namespace_part(type : String, namespace : String) : String
      case type
      when .in?(LOWERCASE_NAMESPACE_TYPES)
        namespace.downcase
      when .in?(UPCASE_NAMESPACE_TYPES)
        namespace.upcase
      else
        namespace
      end
    end

    # A substring that identifies a Databricks MLflow tracking server.
    DATABRICKS_HOST = "databricks"

    # Apply the normalization rules that depend on another component.
    #
    # An mlflow model name takes its case from the tracking server: the type
    # definition says that for Azure ML the name "is case sensitive and shall
    # be kept as-is in the package URL; and for Databricks, it is case
    # insensitive and shall be lowercased in the package URL". Only
    # `repository_url` says which server it is, so this rule cannot live in
    # `normalize_name`, which sees the name alone.
    def self.normalize_name_for_qualifiers(type : String, name : String, qualifiers : Hash(String, String)?) : String
      return name unless type == "mlflow"
      url = qualifiers.try(&.["repository_url"]?)
      return name unless url && url.downcase.includes?(DATABRICKS_HOST)
      around_encoded_slash(name, &.downcase)
    end

    # Normalize a type-specific version. Most types store the version
    # verbatim, but a few define case-insensitive version semantics.
    def self.normalize_version(type : String, version : String) : String
      case type
      when .in?(LOWERCASE_VERSION_TYPES)
        version.downcase
      when "oci"
        # OCI versions are typically a `sha256:...` digest which is
        # case-insensitive; lowercase only when it looks like a digest.
        version.starts_with?("sha256:") ? version.downcase : version
      else
        version
      end
    end

    # Types whose `subpath_definition` sets `case_sensitive: false`. The type
    # definition schema says that for such a component "the valid form is
    # lowercase".
    LOWERCASE_SUBPATH_TYPES = %w[otp]

    # Normalize a caller-supplied subpath. Like the version and qualifier
    # values passed to the constructor, it is taken as decoded text: each `/` separates two
    # literal segments and a `%` is a literal percent sign that serializes as
    # `%25`. Nothing is percent-decoded here, so a subpath rebuilt from its
    # own getter is unchanged. Traversal stays impossible because `.` and `..`
    # segments are discarded, and an encoded `%2E%2E` is just a literal
    # segment that `#to_s` writes back as `%252E%252E`.
    def self.normalize_subpath(type : String, subpath : String) : String?
      subpath = subpath.downcase if type.in?(LOWERCASE_SUBPATH_TYPES)
      normalize_subpath_segments(subpath.split("/"))
    end

    def self.normalize_subpath_segments(segments : Array(String)) : String?
      # Blank segments are dropped alongside genuinely empty ones: a
      # whitespace-only segment is not a meaningful path component and
      # keeping it would serialize as `%20`, which no canonical purl uses.
      cleaned = segments.reject { |s| s.strip.empty? || s == "." || s == ".." }
      return if cleaned.empty?
      cleaned.join("/")
    end
  end
end
