# TODO: Write documentation for `Purl`
module Purl
  VERSION = "0.1.0"

  class PackageURL
    property type : String
    property namespace : String
    property name : String
    property version : String
    property qualifiers : String
    property subpath : String

    def initialize(type_str : String, namespace : String, name : String, version : String, qualifiers : String, subpath : String)
      @type = type_str
      @namespace = namespace
      @name = name
      @version = version
      @qualifiers = qualifiers
      @subpath = subpath
    end

    def to_s
      # scheme:type/namespace/name@version?qualifiers#subpath
      purl = "#{@type}:#{@namespace}/#{@name}@#{@version}"
      purl += "?#{@qualifiers}" if @qualifiers
      purl += "##{@subpath}" if @subpath

      purl
    end

    def self.parse(purl : String) : PackageURL
      match = purl.match(/^([^:]+):([^\/]+)\/([^\/@]+)\/([^@]+)@([^?#]+)(?:\?([^#]+))?(?:#(.+))?$/)
      raise ArgumentError.new("Invalid Package URL") unless match

      type_s = match[2]
      namespace = match[3]
      name = match[4]
      version = match[5]
      qualifiers = match[6]
      subpath = match[7]

      PackageURL.new(type_s, namespace, name, version, qualifiers, subpath)
    end
  end
end
