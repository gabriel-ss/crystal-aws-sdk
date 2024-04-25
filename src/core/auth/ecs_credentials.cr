module AWS::Auth
  class ECSCredentials
    include CredentialProviderWithRefresh

    class CredentialResponse
      include ::JSON::Serializable

      @[::JSON::Field(key: "AccessKeyId")]
      getter access_key_id : String
      @[::JSON::Field(key: "Expiration")]
      getter expiration : Time?
      @[::JSON::Field(key: "RoleArn")]
      getter role_arn : String
      @[::JSON::Field(key: "SecretAccessKey")]
      getter secret_access_key : String
      @[::JSON::Field(key: "Token")]
      getter token : String
    end

    DEFAULT_LINK_LOCAL_HOST = "169.254.170.2"

    def self.resolve(**_args) : CredentialProvider | Nil
      return unless {"AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", "AWS_CONTAINER_CREDENTIALS_FULL_URI"}.any? { |env| ENV.has_key? env }
      return unless {"AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE", "AWS_CONTAINER_AUTHORIZATION_TOKEN"}.any? { |env| ENV.has_key? env }
      new
    end

    def initialize
      relative_path = ENV["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]?
      full_path = ENV["AWS_CONTAINER_CREDENTIALS_FULL_URI"]?

      @credentials_uri = if !relative_path.nil?
                           URI.new("http", DEFAULT_LINK_LOCAL_HOST, 80, relative_path)
                         else
                           raise Exception.new("Neither a relative or a full path was provided.") if full_path.nil?
                           URI.parse(full_path)
                         end
    end

    def refresh
      token = fetch_token
      headers = token.nil? ? nil : HTTP::Headers{"Authorization" => token}
      response = HTTP::Client.get(@credentials_uri, headers) { |response| CredentialResponse.from_json(response.body_io) }
      @credentials = Credentials.new(
        access_key_id: response.access_key_id,
        secret_access_key: response.secret_access_key,
        session_token: response.token,
        expiration: response.expiration,
      )
    end

    def fetch_token
      unless (path = ENV["AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE"]?).nil?
        return File.read(path).strip
      end

      ENV["AWS_CONTAINER_AUTHORIZATION_TOKEN"]?
    end
  end
end
