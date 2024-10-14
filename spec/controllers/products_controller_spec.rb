require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  let(:url) { 'http://example.com/product' }
  let(:redis) { Redis.new }

  before do
    redis.flushall
    allow(Redis).to receive(:new).and_return(redis)
  end

  describe 'POST #create' do
    context 'when the URL has already been processed' do
      before do
        redis.set(url, 'cached_word_frequency')
      end

      it 'returns the cached word frequency from Redis' do
        post :create, params: { url: url }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"word_frequency":')
        expect(response.body).to include('cached_word_frequency')
      end
    end

    context 'when the URL is valid and description is found' do
      let(:description) { 'This is a test description.' }
      let(:expected_word_freq) { [["a", 1], ["description", 1], ["is", 1], ["test", 1], ["this", 1]] } 

      before do
        allow(controller).to receive(:fetch_amazon_description).with(URI.parse(url)).and_return(description)
      end
    
      it 'returns word frequency and caches it in Redis' do
        post :create, params: { url: url }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"word_frequency":')
        expect(redis.get(url)).not_to be_nil
    
        cached_word_freq = JSON.parse(redis.get(url))
        expect(cached_word_freq).to eq(expected_word_freq)
      end
    end
    

    context 'when the URL is valid but no description is found' do
      before do
        allow(controller).to receive(:fetch_amazon_description).with(URI.parse(url)).and_return(nil)
      end

      it 'returns an unprocessable entity error' do
        post :create, params: { url: url }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('No description for this product')
      end
    end
  end

  describe 'private methods' do
    let(:description) { 'Test description with words.' }
    let(:expected_word_freq) { [["description", 1], ["test", 1], ["with", 1], ["words", 1]]  }

    it 'calculates word frequency correctly' do
      allow(Stopwords::Snowball::Filter).to receive(:new).with('en').and_return(Stopwords::Snowball::Filter.new('en'))
      expect(controller.send(:word_frequency, description)).to eq(expected_word_freq)
    end
  end
end
