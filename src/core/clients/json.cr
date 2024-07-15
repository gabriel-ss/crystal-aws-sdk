require "http/client"
require "http/request"
require "awscr-signer"
require "uri"
require "uuid"
require "../converters/json"
require "./pooled_client"

private module AWS::JSONClient
  alias Signer = Awscr::Signer::Signers::V4

  include PooledClient

  def initialize(
    @target_prefix : String,
    @endpoint_prefix : String,
    @json_version : String,
    @config = Config.new
  )
    @connection_pool = create_connection_pool(@endpoint_prefix, @config)
  end

  def exec(command : String, body : HTTP::Client::BodyType = nil, & : HTTP::Client::Response ->)
    request = HTTP::Request.new("POST", "/", make_headers(command), body)
    exec_with_client(request) { |response| yield response }
  end

  private def make_headers(command)
    HTTP::Headers{
      "X-Amz-Target" => "#{@target_prefix}.#{command}",
      "Content-Type" => "application/x-amz-json-#{@json_version}",
    }
  end
end
