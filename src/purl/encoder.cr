require "uri"

module Purl
  # Handles percent-encoding/decoding of purl components.
  module Encoder
    private MALFORMED_ESCAPE = /%(?![0-9A-Fa-f]{2})/

    # Checks the syntax of percent escapes without decoding the string.
    def self.valid_percent_encoding?(value : String) : Bool
      !MALFORMED_ESCAPE.matches?(value)
    end

    # Decode a component exactly once. URI.decode leaves malformed escapes
    # as literal text, but a PURL's percent escapes must follow RFC 3986.
    def self.decode(value : String) : String
      unless valid_percent_encoding?(value)
        raise Purl::Error.new("Invalid percent-encoding in '#{value}'")
      end
      URI.decode(value)
    end

    # Decode a single segment of a slash-delimited path.
    def self.decode_segment(value : String, component : String) : String
      decoded = decode(value)
      if decoded.includes?('/')
        raise Purl::Error.new("Invalid #{component}: segment '#{value}' contains an encoded slash")
      end
      decoded
    end

    # Percent-encode a decoded component or a single segment of a path.
    def self.encode_literal(value : String) : String
      String.build { |io| percent_encode(value, io) }
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
