module AWS::Auth
  class StaticCredentials
    include CredentialProvider

    def self.resolve(
      aws_access_key_id : String?,
      aws_secret_access_key : String?,
      aws_session_token : String?,
      **_args
    ) : CredentialProvider | Nil
      return if aws_access_key_id.nil? || aws_secret_access_key.nil?
      new(aws_access_key_id, aws_secret_access_key, aws_session_token)
    end

    def initialize(access_key_id : String, secret_access_key : String, session_token : String)
      @credentials = Credentials.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        session_token: session_token,
      )
    end
  end
end
