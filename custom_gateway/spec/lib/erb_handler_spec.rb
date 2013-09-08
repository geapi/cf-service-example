require 'spec_helper'

describe ErbHandler do
  describe "generate_content" do
    it "reads a template and writes an output file with the correct vars" do
      output_file_path = File.expand_path("../../fixtures/manifest.yml", __FILE__)
      content =ErbHandler.new({name: "test"}).generate_content("#{output_file_path}.erb")

      expect(content).to eq("- name: test-service")
    end
  end

  describe "create_hydrated_output_file" do
    it "reads a template and writes an output file with the correct vars" do
      output_file_path = File.expand_path("../../fixtures/manifest.yml", __FILE__)
      ErbHandler.create_hydrated_output_file(output_file_path, {name: "test"})

      File.open(output_file_path, "r") do |f|
        expect(f.read).to eq("- name: test-service")
      end

      File.delete(output_file_path)
    end
  end
end