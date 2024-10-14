class ProductsController < ApplicationController
  before_action :validate_url
 
  def create
    if $redis.exists?(uri)
      render json: { word_frequency: $redis.get(uri) }, status: :ok
    else
      description = fetch_amazon_description(uri)
      if description.nil?
        render json: { error: 'No description for this product' }, status: :unprocessable_entity
      else
        words = word_frequency(description) 

        $redis.set(uri, words, ex:3600)

        render json: { word_frequency: words }, status: :ok
      end
    end
  end

  private

  def create_params
    params.permit(:url)
  end

  def uri
    @uri ||= URI.parse(create_params[:url])
  end

  def validate_url
    render json: { error: 'Invalid or empty URL' }, status: :bad_request if uri.blank?
  end

  def fetch_amazon_description(url)
    response = HTTParty.get(url, headers: { 'User-Agent': 'Mozilla/5.0' })
    parsed_page = Nokogiri::HTML(response.body)

    description = parsed_page.at_css('#productDescription')&.text
    description&.strip if description
  rescue StandardError => e
    Rails.logger.error("Error scraping Amazon URL: #{e.message}")
    nil
  end

  def word_frequency(text)
    words = text.downcase.scan(/\b[a-z]+\b/)
    filter = Stopwords::Snowball::Filter.new 'en'
    words.reject { |word| filter.stopword?(word) }
    words.tally.sort_by { |word, count| [-count, word] }
  end
end
