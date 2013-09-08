require 'erb'

class ErbHandler
  def initialize(vars)
    vars.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def generate_content(path_to_file)
    File.open(path_to_file) do |f|
      ERB.new(f.read).result(binding)
    end
  end

  def self.create_hydrated_output_file(output_file_name, vars)
    content = ErbHandler.new(vars).generate_content("#{output_file_name}.erb")
    File.open(output_file_name, "w") do |f|
      f.write(content)
    end
  end
end