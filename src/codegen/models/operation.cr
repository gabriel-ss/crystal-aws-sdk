class AWS::Codegen::ServiceAPI::Shape::Operation < AWS::Codegen::ServiceAPI::Shape
  include JSON::Serializable

  getter input : Target
  getter output : Target
  getter errors : Array(Target)?
  getter traits : Traits

  class Traits
    include JSON::Serializable

    @[JSON::Field(key: "smithy.api#documentation")]
    getter documentation : String
    @[JSON::Field(key: "smithy.api#http")]
    getter http : HTTP?

    class HTTP
      include JSON::Serializable

      getter method : String
      getter uri : String
      getter code : Int32?
    end
  end
end
