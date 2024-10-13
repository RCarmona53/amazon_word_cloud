require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  let(:url) { 'http://example.com/product' }
  let(:redis) { Redis.new }

  before do
    redis.flushall
    allow(Redis).to receive(:new).and_return(redis)
  end

  describe 'POST #word_cloud' do
    context 'when the URL is blank' do
      it 'returns a bad request error' do
        post :word_cloud, params: { url: '' }
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include('URL cannot be empty')
      end
    end

    context 'when the URL has already been processed' do
      before do
        redis.set(url, true)
      end

      it 'returns a conflict error' do
        post :word_cloud, params: { url: url }
        expect(response).to have_http_status(:conflict)
        expect(response.body).to include('URL has already been processed')
      end
    end

    context 'when the URL is valid and description is found' do
      before do
        allow(controller).to receive(:fetch_amazon_description).with(url).and_return('This is a test description.')
      end

      it 'returns word frequency' do
        post :word_cloud, params: { url: url }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"word_frequency":')
        expect(redis.get(url)).to eq('true')
      end
    end

    context 'when the URL is valid but no description is found' do
      before do
        allow(controller).to receive(:fetch_amazon_description).with(url).and_return(nil)
      end

      it 'returns an unprocessable entity error' do
        post :word_cloud, params: { url: url }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Could not extract description')
      end
    end
  end

  describe 'private methods' do
    let(:description) { 'Test description with words.' }
    let(:cleaned_words) { ['test', 'description', 'with', 'words'] }

    it 'cleans the text correctly' do
      allow(File).to receive(:read).with(Rails.root.join('config', 'stopwords.txt')).and_return("a\nand\nthe\n")
      expect(controller.send(:clean_text, description)).to eq(cleaned_words)
    end

    it 'calculates word frequency correctly' do
      words = ['test', 'test', 'description', 'with', 'words']
      expected_freq = [['test', 2], ['description', 1], ['with', 1], ['words', 1]]
      expect(controller.send(:word_frequency, words)).to eq(expected_freq)
    end
  end
end
