require "rails_helper"

RSpec.describe MoneyConcern do
  # ---------------------------------------------------------------------------
  # Module-level API — callable as MoneyConcern.method_name from helpers/services
  # ---------------------------------------------------------------------------
  describe ".parse_money_string (module-level)" do
    subject(:parse) { described_class.parse_money_string(value) }

    context "with nil" do
      let(:value) { nil }
      it { is_expected.to eq(BigDecimal("0")) }
    end

    context "with blank string" do
      let(:value) { "" }
      it { is_expected.to eq(BigDecimal("0")) }
    end

    context "with a Numeric" do
      let(:value) { 42.5 }
      it { is_expected.to eq(BigDecimal("42.5")) }
    end

    context "with an Integer" do
      let(:value) { 1000 }
      it { is_expected.to eq(BigDecimal("1000")) }
    end

    context "with BRL format (European thousands + comma decimal)" do
      let(:value) { "1.234,56" }
      it { is_expected.to eq(BigDecimal("1234.56")) }
    end

    context "with BRL format with R$ prefix" do
      let(:value) { "R$ 1.234,56" }
      it { is_expected.to eq(BigDecimal("1234.56")) }
    end

    context "with US format (comma thousands + dot decimal)" do
      let(:value) { "1,234.56" }
      it { is_expected.to eq(BigDecimal("1234.56")) }
    end

    context "with simple comma decimal (no thousands)" do
      let(:value) { "1234,56" }
      it { is_expected.to eq(BigDecimal("1234.56")) }
    end

    context "with simple dot decimal (no thousands)" do
      let(:value) { "1234.56" }
      it { is_expected.to eq(BigDecimal("1234.56")) }
    end

    context "with integer-only string" do
      let(:value) { "500" }
      it { is_expected.to eq(BigDecimal("500")) }
    end

    context "with a negative BRL value" do
      let(:value) { "-1.200,00" }
      it { is_expected.to eq(BigDecimal("-1200.00")) }
    end

    context "with a negative dot-decimal value" do
      let(:value) { "-99.99" }
      it { is_expected.to eq(BigDecimal("-99.99")) }
    end

    context "with garbage that cannot be parsed" do
      let(:value) { "abc" }
      it { is_expected.to eq(BigDecimal("0")) }
    end
  end

  # ---------------------------------------------------------------------------
  describe ".format_money_display (module-level)" do
    subject(:format) { described_class.format_money_display(value) }

    context "with nil" do
      let(:value) { nil }
      it { is_expected.to eq("R$ 0,00") }
    end

    context "with zero" do
      let(:value) { BigDecimal("0") }
      it { is_expected.to eq("R$ 0,00") }
    end

    context "with a positive whole amount" do
      let(:value) { BigDecimal("1234") }
      it { is_expected.to eq("R$ 1.234,00") }
    end

    context "with a positive decimal amount" do
      let(:value) { BigDecimal("1234.56") }
      it { is_expected.to eq("R$ 1.234,56") }
    end

    context "with a negative amount" do
      let(:value) { BigDecimal("-150.75") }
      it { is_expected.to match(/-/) }
      it { is_expected.to include("150,75") }
    end

    context "with show_currency: false" do
      subject(:format) { described_class.format_money_display(BigDecimal("50.00"), show_currency: false) }
      it { is_expected.to eq("50,00") }
    end
  end

  # ---------------------------------------------------------------------------
  describe ".valid_money_format? (module-level)" do
    subject(:valid) { described_class.valid_money_format?(value) }

    context "with nil (blank)" do
      let(:value) { nil }
      it { is_expected.to be(true) }
    end

    context "with empty string (blank)" do
      let(:value) { "" }
      it { is_expected.to be(true) }
    end

    context "with a Numeric" do
      let(:value) { 99.0 }
      it { is_expected.to be(true) }
    end

    context "with a valid BRL string" do
      let(:value) { "1.234,56" }
      it { is_expected.to be(true) }
    end

    context "with a valid simple decimal string" do
      let(:value) { "100.00" }
      it { is_expected.to be(true) }
    end

    context "with garbage text" do
      let(:value) { "not-money" }
      it { is_expected.to be(false) }
    end
  end

  # ---------------------------------------------------------------------------
  describe ".extract_currency_symbol (module-level)" do
    subject(:symbol) { described_class.extract_currency_symbol(value) }

    context "with nil" do
      let(:value) { nil }
      it { is_expected.to be_nil }
    end

    context "with a non-String Numeric" do
      let(:value) { 10 }
      it { is_expected.to be_nil }
    end

    context "with R$ prefix" do
      let(:value) { "R$ 100,00" }
      it { is_expected.to include("R") }
    end

    context "with no currency symbol" do
      let(:value) { "100,00" }
      it { is_expected.to be_nil }
    end
  end

  # ---------------------------------------------------------------------------
  # Class-method API — callable on an including model class
  # ---------------------------------------------------------------------------
  describe "class methods on including model" do
    it "exposes parse_money_string on Transaction" do
      expect(Transaction.parse_money_string("1.000,00")).to eq(BigDecimal("1000.00"))
    end

    it "exposes format_money_display on Account" do
      expect(Account.format_money_display(BigDecimal("999.99"))).to eq("R$ 999,99")
    end
  end

  # ---------------------------------------------------------------------------
  # Model integration — before_validation normalization
  # ---------------------------------------------------------------------------
  describe "before_validation normalization via included model" do
    let(:user) { create(:user) }
    let(:asset_type) { create(:account_type, :asset) }
    let(:account) { build(:account, user: user, account_type: asset_type) }

    it "wires normalize_money_attributes as a before_validation callback" do
      # Proves the concern registers the callback on the including model.
      # Note: Account#balance recalculates from entries in test mode, so we
      # verify callback invocation rather than the stored value.
      expect(account).to receive(:normalize_money_attributes).and_call_original
      account.valid?
    end
  end
end
