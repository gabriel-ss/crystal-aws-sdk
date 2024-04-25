module AWS::Auth
  class AssumeRoleCredentials(T)
    include CredentialProviderWithRefresh

    def initialize(
      @region : String,
      @source_credential_provider : CredentialProvider,
      @role_arn : String,
      @role_session_name : String? = nil,
      @duration : Time::Span? = nil,
      @policy : T? = nil
    )
    end

    def refresh
      credentials = assume_role
      @credentials = Credentials.new(
        credentials.access_key_id,
        credentials.secret_access_key,
        credentials.session_token
      )
    end

    private STS_NAMESPACES       = {"sts" => "https://sts.amazonaws.com/doc/2011-06-15/"}
    private CREDENTIALS_XML_PATH = "/sts:AssumeRoleResponse/sts:AssumeRoleResult/sts:Credentials"

    private def signer
      credentials = @source_credential_provider.credentials
      Awscr::Signer::Signers::V4.new("sts", @region, credentials.access_key_id, credentials.secret_access_key, credentials.session_token)
    end

    private def default_role_session_name
      "aws-crystal-session-#{Time.utc.to_unix}"
    end

    private def assume_role
      query_params = HTTP::Params.build do |form|
        form.add("Version", "2011-06-15")
        form.add("Action", "AssumeRole")
        form.add("RoleArn", @role_arn)
        form.add("RoleSessionName", @role_session_name || default_role_session_name)

        @policy.try { |policy| form.add("Policy", policy.to_json) }
        @duration.try { |duration| form.add("DurationSeconds", duration.total_seconds.to_i64.to_s) }
      end

      request = HTTP::Request.new("GET", "/")
      request.query = query_params.to_s
      client = HTTP::Client.new(URI.parse "https://sts.#{@region}.amazonaws.com")
      client.before_request { |request| signer.sign(request) }
      response = client.exec(request)

      raise "Failed to assume role: #{response.body}" unless response.success?

      xml = ::XML.parse(response.body)

      Credentials.new(
        access_key_id: xml.xpath_string("string(#{CREDENTIALS_XML_PATH}/sts:AccessKeyId)", STS_NAMESPACES),
        secret_access_key: xml.xpath_string("string(#{CREDENTIALS_XML_PATH}/sts:SecretAccessKey)", STS_NAMESPACES).delete(" \n"),
        session_token: xml.xpath_string("string(#{CREDENTIALS_XML_PATH}/sts:SessionToken)", STS_NAMESPACES).delete(" \n"),
        expiration: Time.parse_iso8601(xml.xpath_string("string(#{CREDENTIALS_XML_PATH}/sts:Expiration)", STS_NAMESPACES)),
      )
    end
  end
end
