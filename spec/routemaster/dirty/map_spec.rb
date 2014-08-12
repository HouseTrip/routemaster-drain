require 'spec_helper'
require 'spec/support/uses_redis'
require 'routemaster/dirty/map'

describe Routemaster::Dirty::Map do
  uses_redis

  subject { described_class.new(redis) }

  def url(idx) ; "https://example.com/#{idx}" ; end

  def mark_urls(count)
    1.upto(count) do |idx|
      subject.mark(url(idx))
    end
  end

  describe '#mark' do
    it 'passes' do
      expect { subject.mark(url(1)) }.not_to raise_error
    end
  end
  
  describe '#sweep' do
    it 'does not yield with no marks' do
      expect { |b| subject.sweep(&b) }.not_to yield_control
    end

    it 'yields marked URLs' do
      mark_urls(3)
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(3).times
    end

    it 'does not yield if called again' do
      mark_urls(3)
      subject.sweep { |url| true }
      expect { |b| subject.sweep(&b) }.not_to yield_control
    end

    it 'honours "next"' do
      mark_urls(10)
      subject.sweep { |url| next if url =~ /3/ ; true }
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(1).times
    end

    it 'yields the same URL again if the block returns falsy' do
      mark_urls(10)
      subject.sweep { |url| url =~ /7/ ? false : true }
      expect { |b| subject.sweep(&b) }.to yield_with_args(/7/)
    end

    it 'yields again if the block fails' do
      mark_urls(1)
      expect {
        subject.sweep { |url| raise }
      }.to raise_error(RuntimeError)
      expect { |b| subject.sweep(&b) }.to yield_control.exactly(1).times
    end
  end

  describe '#count' do
    it 'is 0 by default' do
      expect(subject.count).to eq(0)
    end

    it 'increases when marking' do
      expect { mark_urls(10) }.to change { subject.count }.by(10)
    end

    it 'decreases when sweeping' do
      mark_urls(10)
      limit = 4
      subject.sweep { |url| (limit -= 1) < 0 ? false : true }
      expect(subject.count).to eq(6)
    end
  end
end