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

    def self.normalize_subpath(subpath : String) : String?
      normalize_subpath_segments(subpath.split("/"))
    end

    def self.decode_and_normalize_subpath(raw : String) : String?
      normalize_subpath_segments(raw.split("/").map { |s| URI.decode(s) })
    end

    def self.normalize_subpath_segments(segments : Array(String)) : String?
      cleaned = segments.reject { |s| s.empty? || s == "." || s == ".." }
      return nil if cleaned.empty?
      cleaned.join("/")
    end
  end
end
