# frozen_string_literal: true

require 'json'
require 'mongo'
require 'rouge'
require 'securerandom'
require 'sinatra'

# The main class for the Paster service
class Paster < Sinatra::Base
  before do
    @client = Mongo::Client.new(['127.0.0.1:27017'],
                                database: 'paster',
                                connect: :direct)
  end

  helpers do
    def base_url
      scheme = request.env['rack.url_scheme']
      host = request.env['HTTP_HOST']
      @base_url ||= "#{scheme}://#{host}"
    end
  end

  get '/' do
    <<~HEREDOC
      Paster

      USAGE:
        - POST "/" #=> post plain code
        - GET "/:key" #=> get raw code
        - GET "/:key/:language" #=> get code with :language syntax highlight
    HEREDOC
  end

  post '/' do
    request.body.rewind
    key = insert request.body.read
    base_url + '/' + key
  end

  get '/:key/:language' do
    highlight(read(params[:key]), params[:language])
  end

  get '/:key' do
    read params[:key]
  end

  #==

  def insert(payload)
    key = generate_key
    @client[:pastes].insert_one(_id: key, code: payload)
    key
  end

  def read(key)
    pastes = @client[:pastes].find(_id: key)
    pastes.first[:code] if pastes.count.positive?
  end

  def generate_key
    loop do
      key = SecureRandom.urlsafe_base64(6, false)
      return key unless collision?(key)
    end
  end

  def collision?(key)
    !read(key).nil?
  end

  def highlight(body, language)
    theme = Rouge::Themes::Base16.mode(:light)
    formatter = Rouge::Formatters::HTMLInline.new(theme)
    begin
      lexer = eval "Rouge::Lexers::#{camelize(language)}.new"
      formatter.format(lexer.lex(body))
    rescue StandardError
      body
    end
  end

  def camelize(string)
    string.split('_').collect(&:capitalize).join
  end
end
