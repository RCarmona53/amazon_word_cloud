class ProductsController < ApplicationController
  require 'nokogiri'
  require 'httparty'
  require 'redis'
  require 'stopwords'

  def initialize
    @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
  end

  def word_cloud
    url = params[:url]

    if url.blank?
      return render json: { error: 'URL cannot be empty' }, status: :bad_request
    end

    if @redis.get(url)
      return render json: { error: 'URL has already been processed' }, status: :conflict
    end

    description = fetch_amazon_description(url)

    if description.nil?
      render json: { error: 'Could not extract description' }, status: :unprocessable_entity
    else
      words = clean_text(description)
      word_freq = word_frequency(words)

      @redis.set(url, true, ex: 60)

      generate_word_cloud(word_freq)
      render json: { word_frequency: word_freq }, status: :ok
    end
  end

  private

  def fetch_amazon_description(url)
    response = HTTParty.get(url, headers: { 'User-Agent': 'Mozilla/5.0' })
    parsed_page = Nokogiri::HTML(response.body)

    description = parsed_page.at_css('#productDescription')&.text
    description&.strip if description
  rescue StandardError => e
    Rails.logger.error("Error scraping Amazon URL: #{e.message}")
    nil
  end

  def clean_text(text)
    words = text.downcase.scan(/\b[a-z]+\b/)
    stop_words = Set.new(File.read(Rails.root.join('config', 'stopwords.txt')).split)
    words.reject { |word| stop_words.include?(word) }
  end

  def word_frequency(words)
    words.tally.sort_by { |word, count| [-count, word] }
  end

  def generate_word_cloud(word_freq)
    File.open('word_freq.txt', 'w') do |file|
      word_freq.each { |word, freq| file.puts "#{word}" }
    end
  end
end
