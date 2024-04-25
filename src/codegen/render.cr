require "ecr"

module AWS::Codegen::Render
  MODEL_TEMPLATE_PATH = Path.join(TEMPLATES_PATH, "model.cr.ecr")

  def self.canonicalize_name(name : String)
    name.split('#').last
  end

  def self.render_type(shapes : Hash(String, ServiceAPI::Shape), target : ServiceAPI::Target)
    render_type(shapes, target.target)
  end

  def self.render_type(shapes : Hash(String, ServiceAPI::Shape), shape_name : String)
    case shape = shapes[shape_name]
    in ServiceAPI::Shape::Blob       then "Bytes"
    in ServiceAPI::Shape::Boolean    then "Bool"
    in ServiceAPI::Shape::Double     then "Float64"
    in ServiceAPI::Shape::Float      then "Float32"
    in ServiceAPI::Shape::Long       then "Int64"
    in ServiceAPI::Shape::Integer    then "Int32"
    in ServiceAPI::Shape::List       then "Array(#{render_type(shapes, shape.member)})"
    in ServiceAPI::Shape::Map        then "Hash(#{render_type(shapes, shape.key)}, #{render_type(shapes, shape.value)})"
    in ServiceAPI::Shape::StringLike then "String"
    in ServiceAPI::Shape::Structure  then canonicalize_name shape_name
    in ServiceAPI::Shape::Timestamp  then "Time"
    in ServiceAPI::Shape::Enum       then "Union(#{canonicalize_name(shape_name)}, String)"
    in ServiceAPI::Shape::ShapeUnion then canonicalize_name shape_name
    in ServiceAPI::Shape             then raise "Unresolved Shape #{shape_name}"
    end
  end

  def self.render_converter(shapes : Hash(String, ServiceAPI::Shape), target : ServiceAPI::Target, module_name : String)
    render_converter(shapes, target.target, module_name)
  end

  def self.render_converter(shapes : Hash(String, ServiceAPI::Shape), shape_name : String, module_name : String)
    case shape = shapes[shape_name]
    when ServiceAPI::Shape::List      then render_converter(shapes, shape.member, module_name).try { |item_converter| "::JSON::ArrayConverter(#{item_converter})" }
    when ServiceAPI::Shape::Map       then render_converter(shapes, shape.value, module_name).try { |value_converter| "::JSON::HashValueConverter(#{value_converter})" }
    when ServiceAPI::Shape::Blob      then "AWS::JSON::Base64Converter"
    when ServiceAPI::Shape::Enum      then "AWS::#{module_name}::Converters::#{canonicalize_name shape_name}"
    when ServiceAPI::Shape::Timestamp then "AWS::JSON::EpochMillisFloatConverter"
    end
  end

  class Module
    getter module_version, module_name, module_file

    def initialize(service : ServiceAPI::Shape::Service)
      @module_version = service.version
      @module_name = service.traits.service.sdk_id
    end

    ECR.def_to_s "src/codegen/templates/module.cr.ecr"
  end

  class QueryClient
    getter module_name, endpoint_prefix, service_version, operations : Hash(String, Operation)

    def initialize(shapes : Hash(String, ServiceAPI::Shape), service : ServiceAPI::Shape::Service)
      @module_name = service.traits.service.sdk_id
      @endpoint_prefix = service.traits.service.endpoint_prefix
      @service_version = service.version
      @operations = service.operations.map { |target| {Render.canonicalize_name(target.target), Operation.new(target, shapes)} }.to_h
    end

    ECR.def_to_s "src/codegen/templates/query/client.cr.ecr"
  end

  class RestJSONClient
    getter module_name, endpoint_prefix, operations : Hash(String, Operation)

    def initialize(shapes : Hash(String, ServiceAPI::Shape), service : ServiceAPI::Shape::Service)
      @module_name = service.traits.service.sdk_id
      @endpoint_prefix = service.traits.service.endpoint_prefix
      @operations = service.operations.map { |target| {Render.canonicalize_name(target.target), Operation.new(target, shapes)} }.to_h
    end

    ECR.def_to_s "src/codegen/templates/rest_json/client.cr.ecr"
  end

  class JSONClient
    getter module_name : String, endpoint_prefix : String, json_version : String, target_prefix : String, operations : Hash(String, Operation)

    def initialize(shapes : Hash(String, ServiceAPI::Shape), service : ServiceAPI::Shape::Service, shape_key : String)
      @module_name = service.traits.service.sdk_id
      @endpoint_prefix = service.traits.service.endpoint_prefix.not_nil!
      @json_version = service.traits.protocol.aws_json1_0? ? "1.0" : "1.1"
      @target_prefix = shape_key.split('#').last
      @operations = service.operations.map { |target| {Render.canonicalize_name(target.target), Operation.new(target, shapes)} }.to_h
    end

    ECR.def_to_s "src/codegen/templates/json/client.cr.ecr"
  end

  class Operation
    getter input_type : String, http_method, path_expression, body_expression, return_type, return_expression

    def initialize(target : ServiceAPI::Target, shapes : Hash(String, ServiceAPI::Shape))
      operation = shapes[target.target].as(ServiceAPI::Shape::Operation)
      input = shapes[operation.input.target].as(ServiceAPI::Shape::Structure)
      output = shapes[operation.output.target].as(ServiceAPI::Shape::Structure) unless operation.output.target == "smithy.api#Unit"

      has_uri_params = input.members.any? { |member| member.[1].traits.try(&.http_uri_param?) || true }
      has_query_params = !input.members.all? { |member| member.[1].traits.try(&.http_query_param.nil?) || true }
      has_header_params = !input.members.all? { |member| member.[1].traits.try(&.http_header.nil?) || true }
      has_body_params = input.members.any? do |member_name, member|
        next false if (traits = member.traits).nil?
        !traits.http_payload? && traits.http_query_param.nil? && traits.http_header.nil?
      end

      @input_type = Render.render_type(shapes, operation.input)
      @http_method = operation.traits.http.try(&.method) || "POST"

      input_payload = input.members.find(&.[1].traits.try(&.http_payload?))
      @body_expression = if input_payload.nil?
                           has_body_params ? "input.to_json" : "nil"
                         else
                           "input.#{input_payload[0].underscore}"
                         end

      request_uri = operation.traits.http.try(&.uri) || "/"
      @path_expression = if has_uri_params
                           path_parts = request_uri.split(/(?:\/{|}\/?)/)
                             .map_with_index { |part, index| index.odd? ? "input.#{part.underscore}" : %("#{part}") }
                           path_parts.pop if path_parts.last == %("")

                           %({#{path_parts.join(", ")}}.join('/'))
                         else
                           %("#{request_uri}")
                         end

      output_payload = output.try(&.members.find(&.[1].traits.try(&.http_payload?)))
      @return_type = if output.nil?
                       "Nil"
                     else
                       output_payload.nil? ? Render.render_type(shapes, operation.output.not_nil!) : "Bytes"
                     end

      @return_expression = if output.nil?
                             ""
                           else
                             output_payload.nil? ? "#{Render.render_type(shapes, operation.output.not_nil!)}.new(::JSON::PullParser.new(body))" : "body.is_a?(IO) ? body.getb_to_end : body.to_slice"
                           end
    end
  end

  class Structure
    getter module_name, shape_name : String, target : ServiceAPI::Shape::Structure, shape_members : Array(ShapeMember)
    getter? has_query_params : Bool, has_header_params : Bool

    def initialize(@module_name : String, @protocol : ServiceAPI::Shape::Service::Protocol, shape_id : String, shapes : Hash(String, ServiceAPI::Shape))
      @target = shapes[shape_id].as(ServiceAPI::Shape::Structure)
      @shape_name = Render.canonicalize_name shape_id
      @has_query_params = !target.members.all? { |member| member.[1].traits.try(&.http_query_param.nil?) || true }
      @has_header_params = !target.members.all? { |member| member.[1].traits.try(&.http_header.nil?) || true }
      @shape_members = target.members
        .map { |member, shape| ShapeMember.new(module_name, member, shape, shapes) }
        .sort_by! { |shape_member| shape_member.is_required? ? -1 : 1 }
    end

    def to_s(io : IO)
      case @protocol
      when .aws_query?                  then ECR.embed "src/codegen/templates/query/model.cr.ecr", io
      when .aws_json1_0?, .aws_json1_1? then ECR.embed "src/codegen/templates/json/model.cr.ecr", io
      when .rest_json1?                 then ECR.embed "src/codegen/templates/rest_json/model.cr.ecr", io
      else                                   raise "Unsupported Protocol"
      end
    end
  end

  class ShapeMember
    getter name, rendered_type : String, property_name, converter : String?, http_query_param : String?, http_header : String?
    getter? is_required : Bool, http_payload : Bool, http_uri_param : Bool, json_serializable : Bool

    def initialize(@module_name : String, @name : String, shape_ref : ServiceAPI::Target, shapes : Hash(String, ServiceAPI::Shape))
      @is_required = shape_ref.traits.try(&.required?) || false

      @http_payload = shape_ref.traits.try(&.http_payload?) || false
      @http_uri_param = shape_ref.traits.try(&.http_uri_param?) || false
      @http_query_param = shape_ref.traits.try(&.http_query_param)
      @http_header = shape_ref.traits.try(&.http_header)

      @json_serializable = !http_payload? && !http_uri_param? && http_query_param.nil? && http_header.nil?

      @rendered_type = Render.render_type(shapes, shape_ref)
      @property_name = name.underscore
      @converter = Render.render_converter(shapes, shape_ref, @module_name)
    end
  end

  class Enum
    getter module_name, shape_name : String, members : Array(Tuple(String, String))

    def initialize(@module_name : String, shape_id : String, shapes : Hash(String, ServiceAPI::Shape))
      @target = shapes[shape_id].as(ServiceAPI::Shape::Enum)
      @shape_name = Render.canonicalize_name shape_id
      @members = @target.members.map { |member, target| {member.downcase.camelcase, target.traits.not_nil!.enum_value.not_nil!} }
    end

    ECR.def_to_s "src/codegen/templates/enum.cr.ecr"
  end

  class ShapeUnion
    getter module_name, shape_name : String, members : Array(Tuple(String, String, String, String?))

    def initialize(@module_name : String, shape_id : String, shapes : Hash(String, ServiceAPI::Shape))
      @target = shapes[shape_id].as(ServiceAPI::Shape::ShapeUnion)
      @shape_name = Render.canonicalize_name shape_id
      # .gsub('-', '_').downcase.camelcase.gsub('.', '_')
      # pp @target.members
      @members = @target.members.map { |member, target| {member.downcase.camelcase, Render.render_type(shapes, target.target), member, Render.render_converter(shapes, target.target, @module_name)} }
    end

    ECR.def_to_s "src/codegen/templates/union.cr.ecr"
  end

  def self.render(shapes : Hash(String, ServiceAPI::Shape))
    service = shapes.find! { |key, value| value.is_a? ServiceAPI::Shape::Service }.last.as(ServiceAPI::Shape::Service)
    module_name = canonicalize_name service.traits.service.sdk_id
    module_file = module_name
    protocol = service.traits.protocol
    Dir.mkdir CODEGEN_OUTPUT_PATH/module_file

    shapes.each do |shape_key, shape|
      case shape
      when ServiceAPI::Shape::Service
        File.open(Path[CODEGEN_OUTPUT_PATH, module_file, "#{module_file}.cr"], "w") { |file| Module.new(service).to_s file }
        File.open(Path[CODEGEN_OUTPUT_PATH, module_file, "client.cr"], "w") do |file|
          case protocol
          when .aws_query?                  then QueryClient.new(shapes, shape).to_s file
          when .aws_json1_0?, .aws_json1_1? then JSONClient.new(shapes, shape, shape_key).to_s file
          when .rest_json1?                 then RestJSONClient.new(shapes, shape).to_s file
          else                                   raise "Unsupported Protocol"
          end
        end
      when ServiceAPI::Shape::Structure
        shape_file = Path[CODEGEN_OUTPUT_PATH, module_file, "#{canonicalize_name(shape_key).underscore}.cr"]
        File.open(shape_file, "w") { |file| Structure.new(module_name, protocol, shape_key, shapes).to_s file }
      when ServiceAPI::Shape::Enum
        shape_file = Path[CODEGEN_OUTPUT_PATH, module_file, "#{canonicalize_name(shape_key).underscore}.cr"]
        File.open(shape_file, "w") { |file| Enum.new(module_name, shape_key, shapes).to_s file }
      when ServiceAPI::Shape::ShapeUnion
        shape_file = Path[CODEGEN_OUTPUT_PATH, module_file, "#{canonicalize_name(shape_key).underscore}.cr"]
        File.open(shape_file, "w") { |file| ShapeUnion.new(module_name, shape_key, shapes).to_s file }
      else
      end
    end
  end
end
