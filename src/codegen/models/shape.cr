require "json"

class AWS::Codegen::ServiceAPI::ShapeReference
  include JSON::Serializable
  getter shape : String
  getter documentation : String?
  getter location : String?
  @[JSON::Field(key: "locationName")]
  getter location_name : String?

  def render_type(shapes : Shapes)
    shapes.render_type self
  end
end

class AWS::Codegen::ServiceAPI::Shapes
  @shape_map : Hash(String, Shape)
  # forward_missing_to @shape_map
  delegate each, "[]", "[]?", to: @shape_map

  def initialize(pull : JSON::PullParser)
    @shape_map = Hash(String, Shape).new(pull)
  end

  def render_type(reference : ShapeReference)
    render_type reference.shape
  end

  def render_type(shape_name : String)
    case shape = self[shape_name]
    in ServiceAPI::Shape::Blob       then "Bytes"
    in ServiceAPI::Shape::Boolean    then "Bool"
    in ServiceAPI::Shape::Double     then "Float64"
    in ServiceAPI::Shape::Float      then "Float32"
    in ServiceAPI::Shape::Long       then "Int64"
    in ServiceAPI::Shape::Integer    then "Int32"
    in ServiceAPI::Shape::List       then "Array(#{render_type(shape.member)})"
    in ServiceAPI::Shape::Map        then "Hash(#{render_type(shape.key)}, #{render_type(shape.value)})"
    in ServiceAPI::Shape::StringLike then shape.enum.nil? ? "String" : shape_name
    in ServiceAPI::Shape::Structure  then shape_name
    in ServiceAPI::Shape::Timestamp  then "Time"
    in ServiceAPI::Shape             then raise "Unresolved Shape"
    end
  end
end

# https://smithy.io/2.0/aws/protocols/aws-json-1_0-protocol.html#shape-serialization
class AWS::Codegen::ServiceAPI::Shape
  include JSON::Serializable

  use_json_discriminator "type", {
    service:   Service,
    operation: Operation,
    blob:      Blob,
    boolean:   Boolean,
    double:    Double,
    float:     Float,
    integer:   Integer,
    list:      List,
    long:      Long,
    map:       Map,
    enum:      Enum,
    union:     ShapeUnion,
    string:    StringLike,
    structure: Structure,
    timestamp: Timestamp,
  }
  getter type : String

  class Blob < Shape
    getter max : Int32?
    getter min : Int32?
  end

  class Boolean < Shape
  end

  class Double < Shape
    getter max : Float64?
    getter min : Float64?
  end

  class Float < Shape
    getter max : Float32?
    getter min : Float32?
  end

  class Integer < Shape
    getter max : Int32?
    getter min : Int32?
  end

  class Long < Shape
    getter max : Int64?
    getter min : Int64?
  end

  class List < Shape
    getter member : Target
  end

  class Map < Shape
    getter key : Target
    getter value : Target
  end

  class Enum < Shape
    getter members : Hash(String, Target) # TODO: get value
  end

  class ShapeUnion < Shape
    getter members : Hash(String, Target)
  end

  class StringLike < Shape
    getter max : Int32?
    getter min : Int32?
    getter pattern : String? # Regex
  end

  class Structure < Shape
    getter members : Hash(String, Target)
  end

  class Timestamp < Shape
  end

  class Unit < Shape
  end
end
