require "json"
require "./models/shape.cr"
require "./models/service.cr"
require "./models/*"
require "./render.cr"
require "file_utils"

module AWS::Codegen
  extend self
  SPECS_PATH          = Path["aws-sdk-js-v3", "codegen", "sdk-codegen", "aws-models"]
  TEMPLATES_PATH      = Path["src", "codegen", "templates"]
  CODEGEN_OUTPUT_PATH = Path["src"]
  CORE_FILES          = %w(aws-sdk.cr codegen core)

  def parse_specs
    specs = [] of Hash(String, ServiceAPI::Shape)

    Dir.new(SPECS_PATH).each_child do |file|
      next unless file.to_s.in? %w(dynamodb.json lambda.json sts.json)

      File.open(SPECS_PATH/file) do |content|
        parser = JSON::PullParser.new(content)
        spec = parser.on_key("shapes") { Hash(String, ServiceAPI::Shape).new(parser) }
        abort "No shapes found in #{SPECS_PATH/file}." if spec.nil?
        specs << spec
      end
    end

    specs
  end

  def main
    Dir.mkdir_p CODEGEN_OUTPUT_PATH
    specs = parse_specs

    generated_files = specs.flat_map do |shapes|
      service = shapes.find! { |key, value| value.is_a? ServiceAPI::Shape::Service }.last.as(ServiceAPI::Shape::Service)
      module_name = Render.canonicalize_name service.traits.service.sdk_id
      [module_name, "#{module_name}.cr"]
    end

    untracked_files = Dir.children(CODEGEN_OUTPUT_PATH) - (CORE_FILES | generated_files)
    abort <<-EOF unless untracked_files.empty?
    The following files currently are not in the list of core files and won't be generated
    during codegen, please add then to the core files list or manually delete then:
    #{untracked_files.map { |file| (CODEGEN_OUTPUT_PATH/file).to_s }.join("\n")}
    EOF

    FileUtils.rm_rf(generated_files.map { |file| CODEGEN_OUTPUT_PATH/file })
    specs.each { |shapes| Render.render shapes }
  end
end

AWS::Codegen.main
