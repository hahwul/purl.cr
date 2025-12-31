# A Crystal implementation of the Package URL (purl) specification.
# See: https://github.com/package-url/purl-spec
require "uri"

module Purl
  VERSION = "0.1.0"

  # Represents a Package URL as defined by the purl specification.
  #
  # A Package URL is a URL string used to identify and locate a software package
  # in a mostly universal and uniform way across programming languages.
  #
  # Format: pkg:type/namespace/name@version?qualifiers#subpath
  #
  # Example:
  # ```
  # purl = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1", nil, nil)
  # purl.to_s # => "pkg:npm/%40angular/animation@12.3.1"
  # ```
  class PackageURL
    SCHEME = "pkg"

    property type : String
    property namespace : String?
    property name : String
    property version : String?
    property qualifiers : String?
    property subpath : String?

    def initialize(@type : String, @namespace : String?, @name : String, @version : String? = nil, @qualifiers : String? = nil, @subpath : String? = nil)
    end

    # Returns the Package URL as a string in the purl format.
    def to_s : String
      purl = String.build do |str|
        str << SCHEME << ":" << @type
        if ns = @namespace
          str << "/" << URI.encode_path_segment(ns)
        end
        str << "/" << URI.encode_path_segment(@name)
        if ver = @version
          str << "@" << URI.encode_path_segment(ver)
        end
        if qual = @qualifiers
          str << "?" << qual
        end
        if sub = @subpath
          str << "#" << sub
        end
      end
      purl
    end

    # Parses a Package URL string and returns a PackageURL instance.
    #
    # Raises `ArgumentError` if the string is not a valid Package URL.
    def self.parse(purl : String) : PackageURL
      # Pattern: pkg:type/namespace/name@version?qualifiers#subpath
      # or: pkg:type/name@version?qualifiers#subpath (no namespace)
      match = purl.match(/^pkg:([^\/]+)\/(.+?)(?:@([^?#]+))?(?:\?([^#]+))?(?:#(.+))?$/)
      raise ArgumentError.new("Invalid Package URL") unless match

      type_s = match[1]
      path_part = match[2]
      version = match[3]?.try { |v| URI.decode(v) }
      qualifiers = match[4]?
      subpath = match[5]?

      # Parse namespace and name from path
      path_segments = path_part.split("/")
      if path_segments.size >= 2
        name = URI.decode(path_segments.pop)
        namespace = URI.decode(path_segments.join("/"))
      else
        name = URI.decode(path_segments[0])
        namespace = nil
      end

      PackageURL.new(type_s, namespace, name, version, qualifiers, subpath)
    end
  end
end
