module AWS::Auth
  class EC2Credentials
    include CredentialProviderWithRefresh

    private struct CredentialResponse
      include ::JSON::Serializable

      @[::JSON::Field(key: "AccessKeyId")]
      getter access_key_id : String
      @[::JSON::Field(key: "Expiration")]
      getter expiration : Time?
      @[::JSON::Field(key: "SecretAccessKey")]
      getter secret_access_key : String
      @[::JSON::Field(key: "Token")]
      getter token : String
    end

    DEFAULT_LINK_LOCAL_HOST   = "169.254.169.254"
    SECURITY_CREDENTIALS_PATH = "/latest/meta-data/iam/security-credentials"
    SECURITY_CREDENTIALS_URI  = URI.new("http", DEFAULT_LINK_LOCAL_HOST, path: SECURITY_CREDENTIALS_PATH)

    def self.resolve(**_args) : CredentialProvider | Nil
      client = HTTP::Client.new(URI.new("http", DEFAULT_LINK_LOCAL_HOST))
      client.connect_timeout = 1.seconds
      client.exec("GET", "/")

      new
    rescue IO::TimeoutError
      nil
    end

    def imds_token
      HTTP::Client.put("http://169.254.169.254/latest/api/token", HTTP::Headers{"X-aws-ec2-metadata-token-ttl-seconds" => "21600"}).body
    end

    def initialize
      headers = HTTP::Headers{"X-aws-ec2-metadata-token" => imds_token}
      @role_name = HTTP::Client.get(SECURITY_CREDENTIALS_URI, headers).body
    end

    def refresh
      headers = HTTP::Headers{"X-aws-ec2-metadata-token" => imds_token}
      security_uri = URI.new("http", DEFAULT_LINK_LOCAL_HOST, path: "#{SECURITY_CREDENTIALS_PATH}/#{@role_name}")
      response = HTTP::Client.get(security_uri, headers) { |response| CredentialResponse.from_json(response.body_io) }
      @credentials = Credentials.new(
        access_key_id: response.access_key_id,
        secret_access_key: response.secret_access_key,
        session_token: response.token,
        expiration: response.expiration,
      )
    end
  end
end
