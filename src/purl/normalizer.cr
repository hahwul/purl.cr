require "uri"

module Purl
  # Handles type-specific normalization of purl components.
  module Normalizer
    # Matches the literal "%2F" marker that stands in for an encoded slash
    # inside a decoded namespace or name segment (see `Encoder.decode_segment`).
    ENCODED_SLASH = /%2[Ff]/

    def self.normalize_name(type : String, name : String) : String
      around_encoded_slash(name) { |part| normalize_name_part(type, part) }
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
      return yield value unless value.matches?(ENCODED_SLASH)
      value.split(ENCODED_SLASH).map { |part| yield part }.join("%2F")
    end

    # Types whose name is declared case-insensitive and must be lowercased.
    LOWERCASE_NAME_TYPES = %w[
      alpm apk bitbucket bitnami composer deb github golang hex luarocks npm oci
    ]

    # Types whose namespace is declared case-insensitive and must be lowercased.
    LOWERCASE_NAMESPACE_TYPES = %w[
      alpm apk bitbucket composer deb github golang hex luarocks npm qpkg rpm
    ]

    # Types whose namespace must be uppercased. `cpan` namespaces are CPAN
    # author IDs (CPANIDs), which the spec requires in uppercase.
    UPCASE_NAMESPACE_TYPES = %w[cpan]

    private def self.normalize_name_part(type : String, name : String) : String
      case type
      when "pypi"
        name.gsub('_', '-').downcase
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

    # Normalize a type-specific version. Most types store the version
    # verbatim, but a few define case-insensitive version semantics.
    def self.normalize_version(type : String, version : String) : String
      case type
      when "huggingface"
        # The model ref / commit is case-insensitive per the spec.
        version.downcase
      when "oci"
        # OCI versions are typically a `sha256:...` digest which is
        # case-insensitive; lowercase only when it looks like a digest.
        version.starts_with?("sha256:") ? version.downcase : version
      else
        version
      end
    end

    # Normalize a caller-supplied subpath. Decodes each segment so a
    # traversal marker hidden behind percent-encoding (e.g. %2E%2E) can't
    # bypass the `..` filter, and re-splits on any decoded slash (e.g. an
    # encoded `%2E%2E%2Fbar` segment becomes ["..", "bar"] — the leading
    # `..` is then dropped).
    def self.normalize_subpath(subpath : String) : String?
      normalize_subpath_segments(decode_subpath_segments(subpath))
    end

    private def self.decode_subpath_segments(raw : String) : Array(String)
      raw.split("/").flat_map { |seg| URI.decode(seg).split("/") }
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
