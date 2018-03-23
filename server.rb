require 'sinatra/auth/github'
require 'sinatra/assetpack'
require 'redcarpet'
require 'sass'
require 'yaml'
require 'pp'
require 'base64'
require 'typhoeus'

require_relative 'helpers.rb'

class AddALicense < Sinatra::Base
  set :root, File.dirname(__FILE__)
  enable :sessions

  DEPENDENCY_PATH = File.join(File.dirname(__FILE__), 'deps')
  LICENSES_HASH = YAML.load(File.read(File.join(DEPENDENCY_PATH, 'licenses.yml')))

  configure :development, :testing do
    set :session_secret, 'JUST_FOR_FIXING'
  end

  register Sinatra::AssetPack
  assets {
    js :app, [
      '/js/*.js'
    ]

    css :application, [
      '/css/*.css'
    ]

    js_compression :closure, :level => 'SIMPLE_OPTIMIZATIONS'
    css_compression :sass
  }

  set :github_options, {
    :scopes    => 'public_repo, read:org',
    :secret    => ENV['GH_ADDALICENSE_SECRET_ID'],
    :client_id => ENV['GH_ADDALICENSE_CLIENT_ID'],
    :callback_url => '/callback'
  }

  register Sinatra::Auth::Github

  # trim trailing slashes
  before do
    Octokit.auto_paginate = true
    request.path_info.sub! %r{/$}, ''
  end

  not_found do
    markdown :notfound
  end

  # for all markdown files, keep using layout.erb
  set :markdown, :layout_engine => :erb

  def name
    @github_user.api.user.name || @github_user.api.user.login
  end

  def login
    @github_user.api.user.login
  end

  def email
    @github_user.api.user.email || ''
  end

  def api_client
    @github_user.api
  end

  get '/' do
    markdown :index
  end

  get '/add' do
    authenticate! unless authenticated?
    @github_user = github_user
    erb :add, :locals => { :login => login, :licenses => LICENSES_HASH }
  end

  get '/callback' do
    if authenticated?
      redirect '/add'
    else
      authenticate!
    end
  end

  get '/repos' do
    authenticate! unless authenticated?
    @github_user = github_user
    erb :repos, :layout => false
  end

  post '/add-licenses' do
    authenticate! unless authenticated?
    @github_user = github_user
    license = File.read(File.join(DEPENDENCY_PATH, 'licenses', "#{params['license']}.txt"))

    license.gsub!(/\[year\]/, Time.new.year.to_s)
    license.gsub!(/\[login\]/, login)
    license.gsub!(/\[email\]/, email)
    license.gsub!(/\[fullname\]/, name)

    message = params['message'].empty? ? 'Add license file via addalicense.com' : params['message']
    license_hash = LICENSES_HASH.detect { |l| l[:link] == params['license'] }
    filename = license_hash[:filename] || params['filename']

    params['repositories'].each do |repo|
      repo_info = api_client.repository(repo)
      name = repo_info.name
      description = repo_info.description || ''

      license.gsub!(/\[project\]/, name)
      license.gsub!(/\[description\]/, description)

      api_client.create_content(repo, filename, message, license)
    end

    redirect '/finished'
  end

  get '/finished' do
    markdown :finished
  end

  get '/about' do
    markdown :about
  end

  get '/logout' do
    logout!
    redirect '/'
  end

  helpers { include Helper }
end
