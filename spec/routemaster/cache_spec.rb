require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/cache'
require 'routemaster/fetcher'

describe Routemaster::Cache do
  uses_dotenv
  uses_redis

  let(:fetcher) { double 'fetcher' }
  let(:url) { make_url(1) }
  let(:listener) { double 'listener' }
  subject { described_class.new(fetcher: fetcher) }

  def make_url(idx)
    "https://example.com/stuff/#{idx}"
  end

  def make_response(idx)
    Hashie::Mash.new(
      status:   200,
      headers:  {},
      body:     { id: 123, t: idx }
    )
  end

  shared_examples 'a response getter' do 
    before do
      @counter = 0
      allow(fetcher).to receive(:get) do |url, **options|
        make_response(@counter += 1)
      end
    end

    it 'fetches the url' do
      expect(fetcher).to receive(:get).with(url, anything)
      performer.call(url).status
    end

    it 'passes the locale header' do
      expect(fetcher).to receive(:get) do |url, **options|
        expect(options[:headers]['Accept-Language']).to eq('fr')
        make_response(1)
      end
      performer.call(url, locale: 'fr').status
    end

    it 'passes the version header' do
      expect(fetcher).to receive(:get) do |url, **options|
        expect(options[:headers]['Accept']).to eq('application/json;v=33')
        make_response(1)
      end
      performer.call(url, version: 33).status
    end

    it 'uses the cache' do
      expect(fetcher).to receive(:get).once
      3.times { performer.call(url).status }
      expect(performer.call(url).body.t).to eq(1)
    end

    context 'with a listener' do
      before { subject.subscribe(listener) }

      it 'emits :cache_miss' do
        expect(listener).to receive(:cache_miss)
        performer.call(url).status
      end

      it 'misses on different locale' do
        expect(listener).to receive(:cache_miss).twice
        performer.call(url, locale: 'en').status
        performer.call(url, locale: 'fr').status
      end

      it 'emits :cache_miss' do
        allow(listener).to receive(:cache_miss)
        performer.call(url).status
        expect(listener).to receive(:cache_hit)
        performer.call(url).status
      end
    end
  end


  describe '#get' do
    let(:performer) { subject.method(:get) }

    it_behaves_like 'a response getter'
  end


  describe '#fget' do
    let(:performer) { subject.method(:fget) }

    it_behaves_like 'a response getter'
  end


  describe '#bust' do
    it 'causes next get to query' do
      expect(fetcher).to receive(:get).and_return(make_response(1)).exactly(:twice)
      subject.get(url)
      subject.bust(url)
      subject.get(url)
    end

    it 'emits :cache_bust' do
      subject.subscribe(listener, prefix: true)
      expect(listener).to receive(:on_cache_bust).once
      subject.bust(url)
    end
  end
end
