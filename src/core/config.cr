require "ini"
require "json"
require "./auth"
require "log"

module AWS
  DEFAULT_AWS_CONFIG_FILE         = Path[Path.home, ".aws", "config"]
  DEFAULT_SHARED_CREDENTIALS_FILE = Path[Path.home, ".aws", "credentials"]

  Log = ::Log.for(self)

  struct Config
    getter aws_region : String, endpoint_url : String?

    @credentials_provider : Auth::CredentialProvider

    def self.resolve_region(profile_name : String? = nil)
      unless (region = ENV["AWS_REGION"]?).nil?
        return region
      end

      profile = profile_name || "default"
      config_file_path = ENV["AWS_CONFIG_FILE"]? || DEFAULT_AWS_CONFIG_FILE
      credentials_file_path = ENV["AWS_SHARED_CREDENTIALS_FILE"]? || DEFAULT_SHARED_CREDENTIALS_FILE

      if File.exists? credentials_file_path
        profile_data = File.open(credentials_file_path) { |file| INI.parse(file)[profile]? }
        return region unless (region = profile_data.try(&.["region"]?)).nil?
      end

      if File.exists? config_file_path
        profile_data = File.open(config_file_path) { |file| INI.parse(file)["profile #{profile}"]? }
        return region unless (region = profile_data.try(&.["region"]?)).nil?
      end

      raise "AWS region could not be inferred from environment."
    end

    private PROVIDERS = {Auth::StaticCredentials, Auth::EnvCredentials, Auth::SharedCredentials, Auth::ECSCredentials, Auth::EC2Credentials}

    def self.resolve_credentials_provider(auth_options : Auth::Options)
      PROVIDERS.each do |provider|
        unless (resolved_provider = provider.resolve(**auth_options)).nil?
          return resolved_provider
        end
      end

      raise "No valid credentials were found."
    end

    def initialize(
      profile_name : String? = nil,
      aws_region : String? = nil,
      endpoint_url : String? = nil,
      aws_access_key_id : String? = nil,
      aws_secret_access_key : String? = nil,
      aws_session_token : String? = nil
    )
      @aws_region = aws_region || self.class.resolve_region(profile_name)
      @endpoint_url = endpoint_url
      @credentials_provider = self.class.resolve_credentials_provider({
        profile_name:          profile_name || "default",
        aws_region:            @aws_region,
        endpoint_url:          endpoint_url,
        aws_access_key_id:     aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key,
        aws_session_token:     aws_session_token,
      })
    end

    def credentials : Auth::Credentials
      @credentials_provider.credentials
    end
  end
end
