require "rails_helper"

RSpec.describe Notifications::Adapters::TestAdapter do
  describe "#send_message" do
    it "records the message in memory instead of sending anything" do
      described_class.new.send_message(to: "+5511999999999", body: "Sua vez chegou!")

      expect(described_class.messages).to contain_exactly(
        { to: "+5511999999999", body: "Sua vez chegou!" }
      )
    end
  end

  describe ".clear!" do
    it "empties out previously recorded messages" do
      described_class.new.send_message(to: "+5511999999999", body: "oi")
      described_class.clear!

      expect(described_class.messages).to be_empty
    end
  end
end
