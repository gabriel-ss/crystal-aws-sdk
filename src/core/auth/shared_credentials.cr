module AWS::Auth
  class SharedCredentials
    include CredentialProvider

    @profile_data : Hash(String, String)

    def self.resolve(profile_name : String, **_args) : CredentialProvider | Nil
      profile_data = load_profile(profile_name)
      return if profile_data.nil?

      if source_profile = profile_data["source_profile"]?
        return AssumeRoleCredentials(Nil).new(
          profile_data["region"],
          new(profile: source_profile),
          profile_data["role_arn"],
        )
      end

      new(profile_data)
    end

    protected def self.load_profile(profile : String)
      config_file_path = ENV["AWS_CONFIG_FILE"]? || DEFAULT_AWS_CONFIG_FILE
      credentials_file_path = ENV["AWS_SHARED_CREDENTIALS_FILE"]? || DEFAULT_SHARED_CREDENTIALS_FILE

      if File.exists? credentials_file_path
        profile_data = File.open(credentials_file_path) { |file| INI.parse(file)[profile]? }
        return profile_data unless profile_data.nil?
      end

      return File.open(config_file_path) { |file| INI.parse(file)["profile #{profile}"]? } if File.exists? config_file_path
    end

    def initialize(profile)
      @profile_data = self.class.load_profile(profile).not_nil!
    end

    private def initialize(@profile_data : Hash(String, String)); end

    def credentials : Credentials
      Credentials.new(
        access_key_id: @profile_data["aws_access_key_id"],
        secret_access_key: @profile_data["aws_secret_access_key"],
        session_token: @profile_data["aws_session_token"]?
      )
    end
  end
end
