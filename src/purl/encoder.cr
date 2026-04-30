require "uri"

module Purl
  # Handles percent-encoding/decoding of purl components.
  module Encoder
    # Characters that should NOT be percent-encoded in qualifier values (beyond unreserved chars)
    # Per spec: qualifier values are percent-encoded strings, but `:` and `/` should not be encoded
    QUALIFIER_VALUE_SAFE = ":/"

    # Sentinel character used to preserve %2F / %2f markers across decode→encode
    # round-trips. The character is U+0001, which is forbidden in valid purl
    # input (control characters are not permitted in segments) so it cannot
    # collide with caller data.
    SLASH_SENTINEL = "\u0001"

    # Decode a path segment of a purl while preserving %2F (and %2f) as a
    # literal "%2F" marker. The purl spec requires that an encoded slash
    # inside a segment NOT be conflated with the segment separator: e.g.
    # `pkg:npm/foo%2Fbar/baz` and `pkg:npm/foo/bar/baz` are distinct purls.
    # Returning a string with embedded "%2F" lets the encoder round-trip
    # the marker back out unchanged.
    def self.decode_segment(value : String) : String
      raise Purl::Error.new("Invalid character in segment") if value.includes?(SLASH_SENTINEL)
      protected_input = value.gsub(/%2[Ff]/, SLASH_SENTINEL)
      decoded = URI.decode(protected_input)
      decoded.gsub(SLASH_SENTINEL, "%2F")
    end

    # Percent-encode a purl component (namespace segment, name, version).
    # Encodes all characters except unreserved characters (RFC 3986). Any
    # embedded "%2F" markers are passed through verbatim so a slash that
    # was encoded inside a segment stays encoded after round-tripping.
    def self.encode_component(value : String) : String
      return URI.encode_path_segment(value) unless value.includes?('%')

      String.build do |io|
        cursor = 0
        i = 0
        while i <= value.size - 3
          if value[i]? == '%' && (h = value[i + 1]?) && (l = value[i + 2]?) &&
             h == '2' && (l == 'F' || l == 'f')
            io << URI.encode_path_segment(value[cursor...i]) if i > cursor
            io << "%2F"
            i += 3
            cursor = i
          else
            i += 1
          end
        end
        io << URI.encode_path_segment(value[cursor..]) if cursor < value.size
      end
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
