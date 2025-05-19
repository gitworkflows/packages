# frozen_string_literal: true

module Ecosystem
  class Vcpkg < Base
    def sync_in_batches?
      true
    end

    def install_command(package, _version = nil)
      ".\vcpkg install #{package.name}"
    end

    def check_status(package)
      name = package.is_a?(Package) ? package.name : package['Name']
      return 'removed' unless packages.find { |package| package["Name"] == name }
    end

    def packages
      @packages ||= get_json("https://vcpkg.io/output.json")['Source']
    end

    def all_package_names
      packages.map { |package| package["Name"] }.uniq
    end

    def recently_updated_package_names
      u = "https://github.com/microsoft/vcpkg/commits/master.atom"
      titles = SimpleRSS.parse(get_raw(u)).items.map(&:title)
      titles.map { |t| t.match(/\[(.*?)\]/) && t.match(/\[(.*?)\]/)[1] }.uniq.compact
    rescue
      []
    end

    def fetch_package_metadata(name)
      packages.find { |package| package["Name"] == name }
    end

    def map_package_metadata(package)
      return false unless package.present?
      {
        name: package["Name"],
        description: Array(package["Description"]).join(' '),
        homepage: package["Homepage"],
        repository_url: repo_fallback("", package["Homepage"]),
        licenses: package['License'],
        version: package["Version"],
        dependencies: package["Dependencies"],
      }
    end

    def versions_metadata(pkg_metadata, existing_version_numbers = [])
      return false unless pkg_metadata.present?
      [
        {
          number: pkg_metadata[:version],
        }
      ]
    end

    def dependencies_metadata(_name, version, mapped_package)
      return false unless mapped_package.present?
      return nil unless mapped_package[:version] == version
      return nil unless mapped_package[:dependencies].present?

      mapped_package[:dependencies].map do |dependency|
        name = dependency.is_a?(Hash) ? dependency['name'] : dependency
        if dependency.is_a?(Hash)
          if dependency['version>=']
            requirement = ">=#{dependency['version>=']}"
          else
            requirement = dependency['version'] || dependency['version-semver'] || dependency['version-date'] || dependency['version-string'] || '*'
          end
        else
          requirement = '*'
        end
        {
          package_name: name,
          requirements: requirement,
          kind: "runtime",
          ecosystem: self.class.name.demodulize.downcase,
        }
      end
    end
  end
end
