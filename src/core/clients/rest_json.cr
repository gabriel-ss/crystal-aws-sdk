require "http/client"
require "http/request"
require "awscr-signer"
require "uri"
require "uuid"
require "../converters/json"
require "./pooled_client"

private module AWS::RestJSONClient
  alias Signer = Awscr::Signer::Signers::V4

  include PooledClient

  def initialize(@endpoint_prefix : String, @config = Config.new)
    @connection_pool = create_connection_pool(@endpoint_prefix, @config)
  end

  def exec(method : String, path : String, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType = nil, query_params : URI::Params? = nil, & : HTTP::Client::Response ->)
    request_headers = body.nil? ? headers : (headers || HTTP::Headers.new).add("content-type", "application/json")

    request = HTTP::Request.new(method, path, request_headers, body)
    request.query = query_params.to_s

    exec_with_client(request) { |response| yield response }
  end

  private def get_error_model(response : HTTP::Client::Response, body : IO | String)
    raw_name = response.headers["X-Amzn-Errortype"]?
    if raw_name.nil?
      pull = ::JSON::PullParser.new(body)
      pull.read_object do |key|
        if key.in?({"__type", "code"})
          raw_name = String.new(pull)
        else
          pull.skip
        end
      end
    end

    /(?:^[^#\n]*#)?(.[^:\n]*)(?::.*$)?/.match!(raw_name.not_nil!)[1]
  end
end
