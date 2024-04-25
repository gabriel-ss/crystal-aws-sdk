require "uri"
require "base64"

module AWS::Core
  module QueryEncoder
    extend self

    def encode(
      value : Bool | Int8 | Int16 | Int32 | Int64 | Int128 | Float32 | Float64 | String,
      params : URI::Params,
      key_path : Array(String)
    )
      params[key_path.join('.')] = value.to_s
    end

    def encode(value : Time, params : URI::Params, key_path : Array(String))
      params[key_path.join('.')] = value.to_rfc3339
    end

    def encode(value : Bytes, params : URI::Params, key_path : Array(String))
      params[key_path.join('.')] = Base64.strict_encode(value)
    end

    def encode(value : Array(T), params : URI::Params, key_path : Array(String)) forall T
      value.each_with_index do |v, i|
        encode(v, params, [*key_path, i.to_s])
      end
    end

    def encode(value : Hash(K, V), params : URI::Params, key_path : Array(String)) forall K, V
      value.each do |k, v|
        encode(k, params, [*key_path, "key"])
        encode(v, params, [*key_path, "value"])
      end
    end
  end
end
