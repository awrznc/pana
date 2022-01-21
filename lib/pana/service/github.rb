class GitHub
  require 'uri'
  require 'net/http'
  require 'json'

  def initialize(github_access_token: '')
    @github_access_token = github_access_token
  end

  def get(uri: '')
    uri_object = URI.parse(uri)
    request = Net::HTTP::Get.new(uri_object.request_uri)
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Authorization'] = "token #{@github_access_token}"

    http_object = Net::HTTP.new(uri_object.hostname, uri_object.port)
    http_object.use_ssl = true
    JSON.parse(http_object.request(request).body)
  end

  def get_repos(account_type, account_name, per_page, page_index)
    self.get(uri: "https://api.github.com/#{account_type}/#{account_name}/repos?per_page=#{per_page}&page=#{page_index}")
  end

  def get_account_information(account_type, account_name)
    self.get(uri: "https://api.github.com/#{account_type}/#{account_name}")
  end
end
