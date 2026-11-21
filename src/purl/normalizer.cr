require "uri"

module Purl
  # Handles type-specific normalization of purl components.
  module Normalizer
    def self.normalize_name(type : String, name : String) : String
      if type.in?(TypeRules::SLASHED_NAME_TYPES)
        return name.split('/', remove_empty: true).join('/')
      end

      name = name.strip('/')
      case type
      when "chrome-extension"
        name.downcase(Unicode::CaseOptions::ASCII)
      when "pypi"
        lowercase(name).gsub(/[-_.]+/, '-')
      when "pub"
        lowercase(name).gsub(/[^a-z0-9_]/, '_')
      when .in?(LOWERCASE_NAME_TYPES)
        lowercase(name)
      else
        name
      end
    end

    def self.normalize_namespace(type : String, namespace : String) : String
      namespace.split('/', remove_empty: true).join('/') do |segment|
        case type
        when .in?(LOWERCASE_NAMESPACE_TYPES)
          lowercase(segment)
        when .in?(UPCASE_NAMESPACE_TYPES)
          segment.upcase
        else
          segment
        end
      end
    end

    # Types whose name is declared case-insensitive and must be lowercased.
    # These are the types whose definition sets `name_definition` to
    # `case_sensitive: false`, plus golang, whose definition keeps the flag
    # true but notes that "the name shall be lowercased".
    LOWERCASE_NAME_TYPES = %w[
      alpm apk bitbucket bitnami brew composer deb github
      golang hex luarocks oci otp vscode-extension
    ]

    # Types whose namespace is declared case-insensitive and must be
    # lowercased, again with golang added for its "shall be lowercased" note.
    LOWERCASE_NAMESPACE_TYPES = %w[
      alpm apk bitbucket brew composer deb github golang hex luarocks qpkg rpm
      vscode-extension yocto
    ]

    # Types whose version is declared case-insensitive and must be lowercased.
    LOWERCASE_VERSION_TYPES = %w[huggingface oci pypi vscode-extension]

    # Types whose namespace must be uppercased. `cpan` namespaces are CPAN
    # author IDs (CPANIDs), which the spec requires in uppercase.
    UPCASE_NAMESPACE_TYPES = %w[cpan]

    private DATABRICKS_DOMAINS = %w[databricks.com azuredatabricks.net]

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
      return name unless url && databricks_host?(url)
      lowercase(name)
    end

    private def self.databricks_host?(url : String) : Bool
      host = URI.parse(url).host.try(&.downcase(Unicode::CaseOptions::ASCII).rchop('.'))
      return false unless host

      DATABRICKS_DOMAINS.any? { |domain| host == domain || host.ends_with?(".#{domain}") }
    rescue URI::Error | OverflowError
      false
    end

    # Normalize a version according to its type's case sensitivity.
    def self.normalize_version(type : String, version : String) : String
      type.in?(LOWERCASE_VERSION_TYPES) ? lowercase(version) : version
    end

    # Types whose `subpath_definition` sets `case_sensitive: false`. The type
    # definition schema says that for such a component "the valid form is
    # lowercase".
    LOWERCASE_SUBPATH_TYPES = %w[otp]

    # The caller supplies decoded text. Empty and dot segments are omitted.
    def self.normalize_subpath(type : String, subpath : String) : String?
      segments = subpath.split('/', remove_empty: true).reject { |s| s == "." || s == ".." }
      return if segments.empty?

      if type.in?(LOWERCASE_SUBPATH_TYPES)
        segments.join('/') { |segment| lowercase(segment) }
      else
        segments.join('/')
      end
    end

    # Unicode's default full lowercasing uses final sigma after a cased
    # character and before the end of a word, skipping case-ignorable characters.
    private FINAL_SIGMA = /((?!\p{Case_Ignorable})\p{Cased}\p{Case_Ignorable}*)Σ(?!\p{Case_Ignorable}*+\p{Cased})/

    private def self.lowercase(value : String) : String
      value = value.gsub(FINAL_SIGMA, "\\1ς") if value.includes?('Σ')
      value.downcase
    end
  end
end
