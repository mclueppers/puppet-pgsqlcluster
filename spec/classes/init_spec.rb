require 'spec_helper'
describe 'pgsqlcluster' do

  context 'with defaults for all parameters' do
    it { should contain_class('pgsqlcluster') }
  end
end
