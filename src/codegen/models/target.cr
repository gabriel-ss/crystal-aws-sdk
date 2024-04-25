class AWS::Codegen::ServiceAPI::Target
  include JSON::Serializable
  getter type : String?
  getter target : String
  getter traits : Traits?

  class Traits
    getter? required, http_payload, http_uri_param
    getter documentation : String?, default : String?, http_query_param : String?, http_header : String?, enum_value : String?

    def initialize(pull : JSON::PullParser)
      @required = false
      @http_uri_param = false
      @http_payload = false

      pull.read_object do |key, key_location|
        case key
        when "smithy.api#enumValue"     then @enum_value = pull.read_string
        when "smithy.api#required"      then @required = true; pull.skip
        when "smithy.api#documentation" then @documentation = pull.read_string
        when "smithy.api#default"       then @default = pull.read_raw
        when "smithy.api#httpLabel"     then @http_uri_param = true; pull.skip
        when "smithy.api#httpQuery"     then @http_query_param = pull.read_string
        when "smithy.api#httpHeader"    then @http_header = pull.read_string
        when "smithy.api#httpPayload"   then @http_payload = true; pull.skip
        else                                 pull.skip
        end
      end
    end
  end
end
