require 'minitest/autorun'
require_relative '../helpers.rb'

describe Helper do
  include Helper

  describe '#title' do
    it 'must return expected title' do
      title.must_equal 'Add a License'
    end

    it 'must set @title' do
      title and @title.must_equal title
    end
  end

  describe '#org_logins' do
    organizations = [
      { login: 'username' },
      { login: 'nickname' },
      { login: 'authname' }
    ]

    it 'must return login values' do
      org_logins(organizations).must_equal ['username', 'nickname', 'authname']
    end
  end
end
