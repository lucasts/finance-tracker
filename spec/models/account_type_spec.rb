require 'rails_helper'

RSpec.describe AccountType, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:role) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_inclusion_of(:role).in_array(%w[asset income expense]) }
  end

  describe 'associations' do
    it { should have_many(:accounts).dependent(:restrict_with_error) }
  end
end
