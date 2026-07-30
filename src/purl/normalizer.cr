require "uri"

module Purl
  # Handles type-specific normalization of purl components.
  module Normalizer
    def self.normalize_name(type : String, name : String) : String
      case type
      when "pypi"
        name.gsub('_', '-').downcase
      when "pub"
        # pub names are lowercased and any char outside [a-z0-9_] becomes '_'.
        name.downcase.gsub(/[^a-z0-9_]/, '_')
      when "npm", "golang", "deb", "github", "bitbucket", "composer", "oci"
        name.downcase
      else
        name
      end
    end

    def self.normalize_namespace(type : String, namespace : String) : String
      normalized =
        case type
        when "npm", "golang", "deb", "rpm", "github", "bitbucket", "composer"
          namespace.downcase
        else
          namespace
        end
      # The canonical purl form must not contain empty path segments, so a
      # namespace like "a//b" collapses to "a/b". This keeps a constructed
      # purl identical to its parsed form.
      normalized.split("/").reject(&.empty?).join("/")
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

    def self.decode_and_normalize_subpath(raw : String) : String?
      normalize_subpath_segments(decode_subpath_segments(raw))
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
