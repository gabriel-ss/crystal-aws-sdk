require "http/client"
require "http/request"
require "awscr-signer"
require "uri"
require "uuid"
require "../converters/json"

private module AWS::RestJSONClient
  alias Signer = Awscr::Signer::Signers::V4

  def initialize(@endpoint_prefix : String, @config = Config.new)
    @base_uri = URI.parse(config.endpoint_url || "https://#{endpoint_prefix}.#{config.aws_region}.amazonaws.com")
  end

  def exec(method : String, path : String, headers : HTTP::Headers? = nil, body : HTTP::Client::BodyType = nil, query_params : URI::Params? = nil, & : HTTP::Client::Response ->)
    request_headers = body.nil? ? headers : (headers || HTTP::Headers.new).add("content-type", "application/json")

    request = HTTP::Request.new(method, path, request_headers, body)
    request.path = path
    request.query = query_params.to_s

    credentials = @config.credentials
    signer = Signer.new(@endpoint_prefix, @config.aws_region, credentials.access_key_id, credentials.secret_access_key, credentials.session_token)

    client = HTTP::Client.new(@base_uri)
    client.before_request { |request| signer.sign(request) }
    client.exec(request) { |response| yield response }
  end
end
