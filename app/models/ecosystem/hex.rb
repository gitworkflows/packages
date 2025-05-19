# frozen_string_literal: true

module Ecosystem
  class Hex < Base
    def registry_url(package, version = nil)
      "#{@registry_url}/packages/#{package.name}/#{version}"
    end

    def download_url(package, version)
      return nil unless version.present?
      "https://repo.hex.pm/tarballs/#{package.name}-#{version}.tar"
    end

    def documentation_url(package, version = nil)
      "http://hexdocs.pm/#{package.name}/#{version}"
    end

    def install_command(package, version = nil)
      "mix hex.package fetch #{package.name} #{version}"
    end

    def all_package_names
      page = 1
      packages = []
      while page < 1000
        r = get("#{@registry_url}/api/packages?page=#{page}", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")})
        break if r == []

        packages += r
        page += 1
      end
      packages.map { |package| package["name"] }
    rescue
      []
    end

    def recently_updated_package_names
      (get("#{@registry_url}/api/packages?sort=inserted_at", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")}).map { |package| package["name"] } +
      get("#{@registry_url}/api/packages?sort=updated_at", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")}).map { |package| package["name"] }).uniq
    rescue
      []
    end

    def fetch_package_metadata(name)
      get("#{@registry_url}/api/packages/#{name}", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")})
    rescue
      false
    end

    def map_package_metadata(package)
      return false unless package && package["meta"]
      links = package["meta"].fetch("links", {}).each_with_object({}) do |(k, v), h|
        h[k.downcase] = v
      end
      {
        name: package["name"],
        homepage: links.except("github").first.try(:last),
        repository_url: links["github"],
        description: package["meta"]["description"],
        licenses: repo_fallback(package["meta"].fetch("licenses", []).join(","), links.except("github").first.try(:last)),
        releases: package['releases'],
        downloads: package['downloads']['all'],
        downloads_period: 'total'
      }
    end

    def versions_metadata(pkg_metadata, existing_version_numbers = [])
      pkg_metadata[:releases].reject{|v| existing_version_numbers.include?(v['version'])}.sort_by{|v| v['version'] }.reverse.first(50).map do |version|
        vers = get("#{@registry_url}/api/packages/#{pkg_metadata[:name]}/releases/#{version["version"]}")
        return nil if vers.blank?
        {
          number: version["version"],
          published_at: version["inserted_at"],
          integrity: "sha256-" + vers['checksum'],
          metadata: {
            downloads: vers['downloads']
          }
        }
      end.compact
    end

    def dependencies_metadata(name, version, _package)
      deps = get("#{@registry_url}/api/packages/#{name}/releases/#{version}", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")})["requirements"]
      return [] if deps.nil?

      deps.map do |k, v|
        {
          package_name: k,
          requirements: v["requirement"],
          kind: "runtime",
          optional: v["optional"],
          ecosystem: self.class.name.demodulize.downcase,
        }
      end
    end

    def maintainers_metadata(name)
      json = get("#{@registry_url}/api/packages/#{name}", headers: {"Authorization" => REDIS.get("hex_api_key_#{@registry.id}")})
      json['owners'].map do |user|
        {
          uuid: user["username"],
          login: user["username"],
          email: user["email"]
        }
      end
    rescue StandardError
      []
    end

    def maintainer_url(maintainer)
      "#{@registry_url}/users/#{maintainer.login}"
    end
  end
end
