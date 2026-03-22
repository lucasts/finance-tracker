require 'rails_helper'

RSpec.describe AccountType, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[asset income expense]) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:accounts).dependent(:restrict_with_error) }
  end
end
