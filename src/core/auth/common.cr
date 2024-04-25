module AWS::Auth
  alias Options = NamedTuple(
    profile_name: String,
    aws_region: String,
    endpoint_url: String?,
    aws_access_key_id: String?,
    aws_secret_access_key: String?,
    aws_session_token: String?,
  )

  class Credentials
    getter access_key_id, secret_access_key, session_token, expiration

    def initialize(
      @access_key_id : String,
      @secret_access_key : String,
      @session_token : String? = nil,
      @expiration : Time? = nil
    )
    end
  end

  module CredentialProvider
    def credentials : Credentials
      @credentials
    end
  end

  module CredentialProviderWithRefresh
    include CredentialProvider

    EXPIRATION_LIMIT = Time::Span.new(minutes: 5)

    @mutex = Mutex.new

    def should_refresh?
      return true if (credentials = @credentials).nil?
      return false if (expiration = credentials.expiration).nil?

      Time.utc - expiration < EXPIRATION_LIMIT
    end

    def credentials : Credentials
      if should_refresh?
        @mutex.synchronize do
          refresh if should_refresh?
        end
      end

      @credentials.not_nil!
    end
  end
end
