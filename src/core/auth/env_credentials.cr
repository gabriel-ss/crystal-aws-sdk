module AWS::Auth
  class EnvCredentials
    include CredentialProvider

    def self.resolve(**_args) : CredentialProvider | Nil
      new if {"AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"}.all? { |env| ENV.has_key? env }
    end

    def initialize
      @credentials = Credentials.new(
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
        session_token: ENV["AWS_SESSION_TOKEN"]?,
      )
    end
  end
end
