# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'gourmestre webapp' do
  context 'With minimal parameter' do
    let(:manifest) do
      <<-PUPPET
      include gourmestre
      PUPPET
    end
  end
end
