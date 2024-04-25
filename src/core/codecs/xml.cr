require "xml"

def Nil.from_aws_sdk_xml_input(reader : XML::Reader)
  reader.next
  nil
end

def Bool.from_aws_sdk_xml_input(reader : XML::Reader)
  consume_element_from(reader) do
    case value = reader.value
    when "true"  then true
    when "false" then false
    else              raise "#{value} is not a valid boolean"
    end
  end
end

{% for type, method in {
                         "Int8"    => "i8",
                         "Int16"   => "i16",
                         "Int32"   => "i32",
                         "Int64"   => "i64",
                         "Int128"  => "i128",
                         "UInt8"   => "u8",
                         "UInt16"  => "u16",
                         "UInt32"  => "u32",
                         "UInt64"  => "u64",
                         "UInt128" => "u128",
                         "Float32" => "f32",
                         "Float64" => "f64",
                       } %}
    def {{type.id}}.from_aws_sdk_xml_input(reader : XML::Reader)
      consume_element_from(reader, &.value.to_{{method.id}})
    end

    def {{type.id}}.from_aws_sdk_xml_object_key?(key : String)
      key.to_{{method.id}}?
    end
  {% end %}

def String.from_aws_sdk_xml_input(reader : XML::Reader)
  consume_element_from(reader, &.value)
end

def String.from_aws_sdk_xml_object_key?(key : String) : String
  key
end

def Array.from_aws_sdk_xml_input(reader : XML::Reader)
  collection = new
  outer_depth = reader.depth

  reader.read
  until reader.depth == outer_depth
    next reader.read unless reader.node_type.element?
    collection << T.new({{reader}})
  end

  reader.read
  collection
end

def Hash.from_aws_sdk_xml_input(reader : XML::Reader)
  hash = new
  outer_depth = reader.depth
  reader.read

  until reader.depth == outer_depth
    next reader.read unless reader.node_type.element?

    key = K.from_aws_sdk_xml_object_key?(reader.name)
    raise "Can't convert #{key.inspect} into #{K}" if key.nil?

    hash[key] = V.new(reader)
  end

  reader.read
  hash
end

def Time.from_aws_sdk_xml_input(reader : XML::Reader)
  consume_element_from(reader) { Time.parse_iso8601 reader.value }
end

def consume_element_from(reader : XML::Reader, &)
  element_depth = reader.depth

  while reader.node_type == XML::Reader::Type::ELEMENT
    reader.read
  end

  value = yield reader

  until reader.depth == element_depth && reader.node_type == XML::Reader::Type::END_ELEMENT
    reader.read
  end
  reader.read

  value
end

def Union.from_aws_sdk_xml_input(reader : XML::Reader)
  value = consume_element_from(reader, &.value)

  {% begin %}
    {% if T.includes? Bool %}
    return true if value == "true"
    return false if value == "false"
    {% end %}
    {% type_map = {
         "Int128"  => "i128",
         "UInt128" => "u128",
         "Int64"   => "i64",
         "UInt64"  => "u64",
         "Int32"   => "i32",
         "UInt32"  => "u32",
         "Int16"   => "i16",
         "UInt16"  => "u16",
         "Int8"    => "i8",
         "UInt8"   => "u8",
         "Float64" => "f64",
         "Float32" => "f32",
       } %}
    {% type_order = [Int128, UInt128, Int64, UInt64, Int32, UInt32, Int16, UInt16, Int8, UInt8, Float64, Float32] %}
    {% for type in type_order.select { |type| T.includes? type } %}
    begin
      return value.to_{{type_map[type]}}
    rescue ArgumentError
    end
    {% end %}

    {% if T.includes? String %}
    return value
    {% end %}
  {% end %}
  raise "Couldn't parse #{self} from #{value}"
end

module AWS::Core
  module XML
    annotation Field
    end

    module Serializable
      annotation Options
      end

      macro included
        def self.from_aws_sdk_xml_input(pull : ::XML::Reader)
          instance = allocate
          instance.initialize(__pull_for_xml_serializable: pull)
          GC.add_finalizer(instance) if instance.responds_to?(:finalize)
          instance
        end
      end

      def initialize(*, __pull_for_xml_serializable reader : ::XML::Reader)
        {% begin %}
          {% properties = {} of Nil => Nil %}
          {% for ivar in @type.instance_vars %}
            {% ann = ivar.annotation(XML::Field) %}
            {% unless ann && ann[:ignore] %}
              {%
                properties[ivar.id] = {
                  key:         ((ann && ann[:key]) || ivar).id.stringify,
                  has_default: ivar.has_default_value?,
                  default:     ivar.default_value,
                  nilable:     ivar.type.nilable?,
                  type:        ivar.type,
                  root:        ann && ann[:root],
                  converter:   ann && ann[:converter],
                }
              %}
            {% end %}
          {% end %}

          # `%var`'s type must be exact to avoid type inference issues with
          # recursively defined serializable types
          {% for name, value in properties %}
            %var{name} = uninitialized ::Union({{value[:type]}})
            %found{name} = false
          {% end %}

          outer_depth = reader.depth
          reader.read

          until reader.depth == outer_depth
            next reader.read unless reader.node_type.element?

            key = reader.name
            case key
            {% for name, value in properties %}
              when {{value[:key]}}
                begin
                  %var{name} =
                    begin
                      {% if value[:converter] %}
                        {{value[:converter]}}.from_xml(reader)
                      {% else %}
                        ::Union({{value[:type]}}).from_aws_sdk_xml_input(reader)
                      {% end %}
                    end
                  %found{name} = true
                end
            {% end %}
            else
              on_unknown_xml_node(reader, key)
            end
          end

          reader.read

          {% for name, value in properties %}
            if %found{name}
              @{{name}} = %var{name}
            else
              {% unless value[:has_default] || value[:nilable] %}
                raise "Missing XML element: {{value[:key].id}}"
              {% end %}
            end
          {% end %}
        {% end %}
        after_initialize
      end

      protected def after_initialize
      end

      protected def on_unknown_xml_node(reader, key)
        reader.next
      end
    end
  end
end
