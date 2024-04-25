require "base64"
require "json"

module AWS::JSON
  module Base64Converter
    def self.from_json(pull : ::JSON::PullParser)
      Base64.decode(pull.read_string)
    end

    def self.to_json(value : Bytes, builder : ::JSON::Builder)
      builder.string do |io|
        Base64.strict_encode(value, io)
      end
    end
  end

  module EpochMillisFloatConverter
    def self.to_json(value : Time, json : ::JSON::Builder) : Nil
      json.number(value.to_unix_ms.to_f / 1000)
    end

    def self.from_json(pull : ::JSON::PullParser)
      Time.unix_ms((pull.read_float * 1000).to_i64)
    end
  end
end
