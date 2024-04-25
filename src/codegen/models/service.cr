require "json"

module ScopedString
  def self.to_json(value : String, json : JSON::Builder) : Nil
    json.string(value)
  end

  def self.from_json(pull : JSON::PullParser)
    pull.read_string.sub(/.*?#/, "")
  end
end

class AWS::Codegen::ServiceAPI::Shape::Service < AWS::Codegen::ServiceAPI::Shape
  include JSON::Serializable

  enum Protocol
    AwsQuery
    AwsJson1_0
    AwsJson1_1
    RestJson1
  end

  getter type : String
  getter version : String

  getter traits : Traits
  getter operations : Array(Target)

  class Traits
    include JSON::Serializable
    include JSON::Serializable::Unmapped

    @[JSON::Field(key: "smithy.api#title")]
    getter title : String
    @[JSON::Field(key: "smithy.api#documentation")]
    getter documentation : String

    getter(signer_version : String) { json_unmapped.keys.find!(&.starts_with? "aws.auth#").lchop "aws.auth#" }
    getter(signer_name : String) { json_unmapped.find!(&.first.starts_with? "aws.auth#").last["name"].as_s }
    getter(protocol : Protocol) { Protocol.parse json_unmapped.keys.find!(&.starts_with? "aws.protocols#").lchop("aws.protocols#") }

    @[JSON::Field(key: "aws.api#service")]
    getter service : Service

    class Service
      include JSON::Serializable

      @[JSON::Field(key: "sdkId")]
      getter sdk_id : String
      @[JSON::Field(key: "arnNamespace")]
      getter arn_namespace : String?
      @[JSON::Field(key: "cloudFormationName")]
      getter cloud_formation_name : String?
      @[JSON::Field(key: "cloudTrailEventSource")]
      getter cloud_trail_event_source : String?
      @[JSON::Field(key: "endpointPrefix")]
      getter endpoint_prefix : String?
    end
  end
end

# class AWS::Codegen::Service
#   def initialize(pull : JSON::PullParser)
#     pull.read_object do |key, key_location|
#       case key
#       when "version" then @version = pull.read_string
#       when "traits" then pull.read_object do |key, key_location|
#         case key
#         when "smithy.api#title"         then @title = pull.read_string
#         when "smithy.api#documentation" then @documentation = pull.read_string
#         when "aws.api#service" then pull.read_object do |key, key_location|
#           case key
#           when "sdkId"                 then @sdk_id = pull.read_string
#           when "arnNamespace"          then @arn_namespace = pull.read_string
#           when "cloudFormationName"    then @cloud_formation_name = pull.read_string
#           when "cloudTrailEventSource" then @cloud_trail_event_source = pull.read_string
#           when "endpointPrefix"        then @endpoint_prefix = pull.read_string
#           else                              pull.skip
#           end
#         end
#         when .starts_with? "aws.auth#"
#           @signer_version = key.lchop "aws.auth#"
#           pull.on_key("name") { @signer_name = pull.read_string }
#         else pull.skip
#         end
#       end
#       else pull.skip
#       end
#     end
#   end
# end

# pp AWS::Codegen::Service.from_json(<<-'JSON')
# {
#   "type": "service",
#   "version": "2015-03-31",
#   "operations": [{ "target": "com.amazonaws.lambda#UpdateFunctionUrlConfig" }],
#   "traits": {
#     "aws.api#service": {
#       "sdkId": "Lambda",
#       "arnNamespace": "lambda",
#       "cloudFormationName": "Lambda",
#       "cloudTrailEventSource": "lambda.amazonaws.com",
#       "endpointPrefix": "lambda"
#     },
#     "aws.auth#sigv4": {
#       "name": "lambda"
#     },
#     "aws.protocols#restJson1": {},
#     "smithy.api#documentation": "<fullname>Lambda</fullname>\n         <p>\n            <b>Overview</b>\n         </p>\n         <p>Lambda is a compute service that lets you run code without provisioning or managing servers.\n        Lambda runs your code on a high-availability compute infrastructure and performs all of the\n      administration of the compute resources, including server and operating system maintenance, capacity provisioning\n      and automatic scaling, code monitoring and logging. With Lambda, you can run code for virtually any\n      type of application or backend service. For more information about the Lambda service, see <a href=\"https://docs.aws.amazon.com/lambda/latest/dg/welcome.html\">What is Lambda</a> in the <b>Lambda Developer Guide</b>.</p>\n         <p>The <i>Lambda API Reference</i> provides information about\n      each of the API methods, including details about the parameters in each API request and\n      response. </p>\n         <p></p>\n         <p>You can use Software Development Kits (SDKs), Integrated Development Environment (IDE) Toolkits, and command\n      line tools to access the API. For installation instructions, see <a href=\"http://aws.amazon.com/tools/\">Tools for\n        Amazon Web Services</a>. </p>\n         <p>For a list of Region-specific endpoints that Lambda supports, \n      see <a href=\"https://docs.aws.amazon.com/general/latest/gr/lambda-service.html/\">Lambda\n        endpoints and quotas </a> in the <i>Amazon Web Services General Reference.</i>. </p>\n         <p>When making the API calls, you will need to\n      authenticate your request by providing a signature. Lambda supports signature version 4. For more information,\n      see <a href=\"https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html\">Signature Version 4 signing process</a> in the\n      <i>Amazon Web Services General Reference.</i>. </p>\n         <p>\n            <b>CA certificates</b>\n         </p>\n         <p>Because Amazon Web Services SDKs use the CA certificates from your computer, changes to the certificates on the Amazon Web Services servers\n        can cause connection failures when you attempt to use an SDK. You can prevent these failures by keeping your\n        computer's CA certificates and operating system up-to-date. If you encounter this issue in a corporate\n        environment and do not manage your own computer, you might need to ask an administrator to assist with the\n        update process. The following list shows minimum operating system and Java versions:</p>\n         <ul>\n            <li>\n               <p>Microsoft Windows versions that have updates from January 2005 or later installed contain at least one\n            of the required CAs in their trust list. </p>\n            </li>\n            <li>\n               <p>Mac OS X 10.4 with Java for Mac OS X 10.4 Release 5 (February 2007), Mac OS X 10.5 (October 2007), and\n            later versions contain at least one of the required CAs in their trust list. </p>\n            </li>\n            <li>\n               <p>Red Hat Enterprise Linux 5 (March 2007), 6, and 7 and CentOS 5, 6, and 7 all contain at least one of the\n            required CAs in their default trusted CA list. </p>\n            </li>\n            <li>\n               <p>Java 1.4.2_12 (May 2006), 5 Update 2 (March 2005), and all later versions, including Java 6 (December\n            2006), 7, and 8, contain at least one of the required CAs in their default trusted CA list. </p>\n            </li>\n         </ul>\n         <p>When accessing the Lambda management console or Lambda API endpoints, whether through browsers or\n        programmatically, you will need to ensure your client machines support any of the following CAs: </p>\n         <ul>\n            <li>\n               <p>Amazon Root CA 1</p>\n            </li>\n            <li>\n               <p>Starfield Services Root Certificate Authority - G2</p>\n            </li>\n            <li>\n               <p>Starfield Class 2 Certification Authority</p>\n            </li>\n         </ul>\n         <p>Root certificates from the first two authorities are available from <a href=\"https://www.amazontrust.com/repository/\">Amazon trust services</a>, but keeping your computer\n        up-to-date is the more straightforward solution. To learn more about ACM-provided certificates, see <a href=\"http://aws.amazon.com/certificate-manager/faqs/#certificates\">Amazon Web Services Certificate Manager FAQs.</a>\n         </p>",
#     "smithy.api#title": "AWS Lambda"
#   }
# }
# JSON
