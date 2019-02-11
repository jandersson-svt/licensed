# frozen_string_literal: true
require "json"
require "English"

module Licensed
  module Source
    class Pip
      VERSION_OPERATORS = %w(< > <= >= == !=).freeze
      PACKAGE_REGEX = /^(\w+)(#{VERSION_OPERATORS.join("|")})?/

      def self.type
        "pip"
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        return unless virtual_env_pip && Licensed::Shell.tool_available?(virtual_env_pip)
        File.exist?(@config.pwd.join("requirements.txt"))
      end

      def dependencies
        @dependencies ||= packages_from_requirements_txt.map do |package_name|
          package = package_info(package_name)
          location = File.join(package["Location"], package["Name"] +  "-" + package["Version"] + ".dist-info")
          Dependency.new(location, {
                           "type"        => Pip.type,
                           "name"        => package["Name"],
                           "summary"     => package["Summary"],
                           "homepage"    => package["Home-page"],
                           "version"     => package["Version"]
                         })
        end
      end

      private

      def packages_from_requirements_txt
        File.open(@config.pwd.join("requirements.txt")).map do |line|
          line.strip.match(PACKAGE_REGEX) { |match| match.captures.first }
        end.compact
      end

      def package_info(package_name)
        p_info = pip_command(package_name).lines
        p_info.each_with_object(Hash.new(0)) { |pkg, a|
          k, v = pkg.split(":", 2)
          next if k.nil? || k.empty?
          a[k.strip] = v&.strip
        }
      end

      def pip_command(*args)
        Licensed::Shell.execute(virtual_env_pip, "--disable-pip-version-check", "show", *args)
      end

      def virtual_env_pip
        return unless virtual_env_dir
        File.join(virtual_env_dir, "bin", "pip")
      end

      def virtual_env_dir
        return @virtual_env_dir if defined?(@virtual_env_dir)
        @virtual_env_dir = begin
          venv_dir = @config.dig("python", "virtual_env_dir")
          File.expand_path(venv_dir, @config.root) if venv_dir
        end
      end
    end
  end
end