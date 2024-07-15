require "http/client"
require "db/pool"
require "awscr-signer"

module AWS::PooledClient
  alias Signer = Awscr::Signer::Signers::V4
  alias Pool = DB::Pool

  N_OF_CONNECTION_RETRIES = 4

  private getter connection_pool : Pool(HTTP::Client)

  private def create_connection_pool(@endpoint_prefix : String, @config = Config.new)
    base_uri = URI.parse(config.endpoint_url || "https://#{endpoint_prefix}.#{config.aws_region}.amazonaws.com")
    Pool.new(Pool::Options.new(
      max_pool_size: @config.max_connection_pool_size,
      max_idle_pool_size: @config.max_idle_connection_pool_size
    )) do
      client = HTTP::Client.new(base_uri, @config.tls_context)
      client.connect_timeout = config.connect_timeout
      client.read_timeout = config.read_timeout

      client.before_request do |request|
        credentials = @config.credentials
        Signer.new(@endpoint_prefix, @config.aws_region, credentials.access_key_id, credentials.secret_access_key, credentials.session_token).sign(request)
      end

      client
    end
  end

  def with_client(& : HTTP::Client -> T) : T forall T
    result = uninitialized T

    N_OF_CONNECTION_RETRIES.times do |current_retry|
      break result = connection_pool.checkout { |client| yield client }
    rescue ex : OpenSSL::SSL::Error
      raise ex if current_retry == N_OF_CONNECTION_RETRIES - 1
      sleep (0.25 + current_retry * 0.25).seconds
    end

    result
  end

  def exec_with_client(*args, **kwargs) : T forall T
    with_client(&.exec(*args, **kwargs))
  end

  def exec_with_client(*args, **kwargs, & : HTTP::Client::Response -> T) : T forall T
    with_client(&.exec(*args, **kwargs) { |response| yield response })
  end
end
