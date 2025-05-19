# frozen_string_literal: true

module Ecosystem
  class Pub < Base
    def registry_url(package, version = nil)
      "#{@registry_url}/packages/#{package.name}" + (version ? "/versions/#{version}" : "")
    end

    def download_url(package, version)
      return nil unless version.present?
      "#{@registry_url}/packages/#{package.name}/versions/#{version}.tar.gz"
    end

    def documentation_url(package, version = nil)
      "#{@registry_url}/documentation/#{package.name}/#{version}"
    end

    def install_command(package, version = nil)
      "dart pub add #{package.name}" + (version ? ":#{version}" : "")
    end

    def all_package_names
      get_json("#{@registry_url}/api/package-names")["packages"]
    rescue
      []
    end

    def recently_updated_package_names
      get("#{@registry_url}/api/packages?page=1")["packages"].map { |package| package["name"] }
    rescue
      []
    end

    def fetch_package_metadata(name)
      get("#{@registry_url}/api/packages/#{name}")
    rescue
      {}
    end

    def map_package_metadata(package)
      latest_version = package["latest"]
      return false if latest_version.nil?
      {
        name: package["name"],
        homepage: latest_version["pubspec"]["homepage"],
        description: latest_version["pubspec"]["description"],
        repository_url: repo_fallback(latest_version["pubspec"]["repository"], latest_version["pubspec"]["homepage"]),
        versions: package["versions"],
        status: package['isDiscontinued'] ? 'discontinued' : nil
      }
    end

    def versions_metadata(pkg_metadata, existing_version_numbers = [])
      pkg_metadata[:versions].map do |v|
        {
          number: v["version"],
          published_at: v['published']
        }
      end
    end

    def dependencies_metadata(_name, version, package)
      vers = package[:versions].find { |v| v["version"] == version }
      return [] if vers.nil?

      map_dependencies(vers["pubspec"].fetch("dependencies", {}), "runtime") +
        map_dependencies(vers["pubspec"].fetch("dev_dependencies", {}), "Development")
    end
  end
end
