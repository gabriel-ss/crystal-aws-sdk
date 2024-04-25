require "http/client"
require "http/request"
require "awscr-signer"
require "uri"
require "uuid"
require "../converters/json"

private module AWS::JSONClient
  alias Signer = Awscr::Signer::Signers::V4

  def initialize(
    @target_prefix : String,
    @endpoint_prefix : String,
    @json_version : String,
    @config = Config.new
  )
    @base_uri = URI.parse(config.endpoint_url || "https://#{endpoint_prefix}.#{config.aws_region}.amazonaws.com")
  end

  def exec(command : String, body : HTTP::Client::BodyType = nil, & : HTTP::Client::Response ->)
    request = HTTP::Request.new("POST", "/", make_headers(command), body)

    credentials = @config.credentials
    signer = Signer.new(@endpoint_prefix, @config.aws_region, credentials.access_key_id, credentials.secret_access_key, credentials.session_token)

    client = HTTP::Client.new(@base_uri)
    client.before_request { |request| signer.sign(request) }
    client.exec(request) { |response| yield response }
  end

  private def make_headers(command)
    HTTP::Headers{
      "X-Amz-Target" => "#{@target_prefix}.#{command}",
      "Content-Type" => "application/x-amz-json-#{@json_version}",
    }
  end
end
