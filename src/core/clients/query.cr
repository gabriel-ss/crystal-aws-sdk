require "http/client"
require "http/request"
require "awscr-signer"
require "uri"
require "uuid"
require "./pooled_client"

private module AWS::QueryClient
  alias Signer = Awscr::Signer::Signers::V4

  include PooledClient

  def initialize(
    @endpoint_prefix : String,
    @service_version : String,
    @config = Config.new
  )
    @connection_pool = create_connection_pool(@endpoint_prefix, @config)
  end

  HEADERS = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}

  def exec(command : String, params : URI::Params = nil, & : HTTP::Client::Response ->)
    params["Action"] = command
    params["Version"] = @service_version
    request = HTTP::Request.new("POST", "/", HEADERS, params.to_s)
    exec_with_client(request) { |response| yield response }
  end

  def parse_response(reader : ::XML::Reader, result_type : T.class, result_node : String) : T forall T
    loop do
      raise "Response node not found in XML" unless reader.read
      break if reader.node_type == ::XML::Reader::Type::ELEMENT && reader.name == result_node
    end
    result_type.from_aws_sdk_xml_input(reader)
  end
end
