require "uri"

module Purl
  # Handles percent-encoding/decoding of purl components.
  module Encoder
    # Matches the "%2F" marker (in either case) that stands for a slash
    # percent-encoded *inside* a single namespace or name segment.
    ENCODED_SLASH = /%2[Ff]/

    # Decode a path segment of a purl while preserving %2F (and %2f) as a
    # literal "%2F" marker. The purl spec requires that an encoded slash
    # inside a segment NOT be conflated with the segment separator: e.g.
    # `pkg:npm/foo%2Fbar/baz` and `pkg:npm/foo/bar/baz` are distinct purls.
    # Returning a string with embedded "%2F" lets the encoder round-trip
    # the marker back out unchanged.
    #
    # The value is split on the encoded slash markers, each piece is decoded
    # independently, and the pieces are rejoined with a canonical "%2F". This
    # cannot collide with any decoded byte (such as a percent-encoded control
    # character like "%01"), unlike a sentinel round-trip.
    def self.decode_segment(value : String) : String
      value.split(ENCODED_SLASH).map { |part| URI.decode(part) }.join("%2F")
    end

    # Percent-encode a purl component (namespace segment, name). Any embedded
    # "%2F" markers are passed through verbatim so a slash that was encoded
    # inside a segment stays encoded after round-tripping.
    def self.encode_component(value : String) : String
      return encode_literal(value) unless value.matches?(ENCODED_SLASH)
      value.split(ENCODED_SLASH).map { |part| encode_literal(part) }.join("%2F")
    end

    # Percent-encode a component that carries no "%2F" marker semantics:
    # the version, and each individual subpath segment.
    #
    # Unlike namespace/name segments, these are fully decoded when parsed —
    # they have no internal segment structure for an encoded slash to be
    # confused with — so a `%` in them is always a literal percent sign.
    # Encoding them with `encode_component` would pass a literal "%2F"
    # through verbatim, and re-parsing would then decode it back into a
    # slash, changing the value.
    def self.encode_literal(value : String) : String
      String.build { |io| percent_encode(value, io) }
    end

    # Qualifier values follow the same rule as every other component: the
    # colon stays as-is, and a slash — which is never a separator inside a
    # value — is encoded. So `repository_url=https://example.com` serializes
    # as `repository_url=https:%2F%2Fexample.com`.
    def self.encode_qualifier_value(value : String) : String
      encode_literal(value)
    end

    # ECMA-427 clause 5.4 lists what is left alone: the alphanumeric
    # characters, the punctuation characters "-", ".", "_" and "~", and the
    # colon ":", which "shall not be percent-encoded ... whether used as a
    # Separator Character or otherwise". Everything else is encoded, including
    # "/" wherever it is not acting as a purl separator.
    private def self.safe_char?(char : Char) : Bool
      char.ascii_alphanumeric? ||
        char == '-' || char == '.' || char == '_' || char == '~' || char == ':'
    end

    private def self.percent_encode(value : String, io : IO) : Nil
      value.each_char do |char|
        if safe_char?(char)
          io << char
        else
          char.each_byte do |byte|
            io << '%'
            io << byte.to_s(16, upcase: true).rjust(2, '0')
          end
        end
      end
    end
  end
end
