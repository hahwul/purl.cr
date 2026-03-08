require "uri"

module Purl
  # Handles percent-encoding/decoding of purl components.
  module Encoder
    # Characters that should NOT be percent-encoded in qualifier values (beyond unreserved chars)
    # Per spec: qualifier values are percent-encoded strings, but `:` and `/` should not be encoded
    QUALIFIER_VALUE_SAFE = ":/"

    # Percent-encode a purl component (namespace segment, name, version).
    # Encodes all characters except unreserved characters (RFC 3986).
    def self.encode_component(value : String) : String
      URI.encode_path_segment(value)
    end

    # Encode qualifier value: similar to encode_component but preserves `:` and `/`
    def self.encode_qualifier_value(value : String) : String
      String.build do |str|
        value.each_char do |c|
          if QUALIFIER_VALUE_SAFE.includes?(c)
            str << c
          elsif c.ascii_alphanumeric? || c == '-' || c == '.' || c == '_' || c == '~'
            str << c
          else
            c.to_s.to_slice.each do |byte|
              str << '%'
              str << byte.to_s(16, upcase: true).rjust(2, '0')
            end
          end
        end
      end
    end
  end
end
