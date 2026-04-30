require "uri"

module Purl
  # Handles type-specific normalization of purl components.
  module Normalizer
    def self.normalize_name(type : String, name : String) : String
      case type
      when "pypi"
        name.gsub('_', '-').downcase
      when "npm", "golang", "deb", "github", "bitbucket"
        name.downcase
      else
        name
      end
    end

    def self.normalize_namespace(type : String, namespace : String) : String
      case type
      when "npm", "golang", "deb", "rpm", "github", "bitbucket"
        namespace.downcase
      else
        namespace
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
      cleaned = segments.reject { |s| s.empty? || s == "." || s == ".." }
      return nil if cleaned.empty?
      cleaned.join("/")
    end
  end
end
