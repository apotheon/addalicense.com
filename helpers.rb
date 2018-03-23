module Helper
  def title number=nil
    @title ||= 'Add a License'
  end

  # doing it in parallel is way more performant
  # rescue block is needed in case a repo is completely empty
  def repositories_missing_licenses
    Octokit.auto_paginate = true
    sorted_public_repos
  end

  private

  # helper helpers

  def sorted_public_repos
    hydra = Typhoeus::Hydra.hydra

    public_repos = repos.flat_map do |repo|
      get_public_repo Typhoeus::Request.new(
        "https://api.github.com/repos/#{repo.full_name}",

        headers: {
          Authorization: "token #{api_client.access_token}",
          Accept: 'application/vnd.github.drax-preview+json'
        }
      )
    end

    hydra.queue request
    hydra.run

    public_repos.sort_by {|repo| repo['full_name'] }
  end

  def get_public_repo request
    public_repo = nil

    request.on_complete do |response|
      if response.success?
        body = JSON.load response.response_body
        public_repo = repo if body['license'].nil?
      elsif response.timed_out?
        puts "#{repo.full_name} got a time out"
      elsif response.code == 0      # no http response; something's wrong
        puts "#{repo.full_name} " + response.curl_error_message
      elsif response.code == 404    # probably empty repo
        public_repo = repo
        puts "404, but that's ok."
      else # unsuccessful http response
        puts "#{repo.full_name} HTTP request failed: " + response.code.to_s
      end
    end

    public_repo
  end

  def org_logins orgs=api_client.organizations
    orgs.collect {|org| org[:login] }
  end

  def repos organization_logins, repositories=api_client.repositories
    organization_logins.each do |org_login|
      repositories.concat api_client.organization_repositories org_login
    end
  end
end
