require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject { described_class.new(user, :dummy_record) }

  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user) }

  context "with no user" do
    let(:user) { nil }

    it "denies every generic action by default" do
      expect(subject.index?).to be false
      expect(subject.show?).to be false
      expect(subject.create?).to be false
      expect(subject.new?).to be false
      expect(subject.update?).to be false
      expect(subject.edit?).to be false
      expect(subject.destroy?).to be false
    end

    it "denies every avo_* action by default" do
      expect(subject.avo_index?).to be_falsy
      expect(subject.avo_show?).to be_falsy
      expect(subject.avo_create?).to be_falsy
      expect(subject.avo_new?).to be_falsy
      expect(subject.avo_update?).to be_falsy
      expect(subject.avo_edit?).to be_falsy
      expect(subject.avo_destroy?).to be_falsy
    end
  end

  context "with a non-admin user" do
    let(:user) { other_user }

    it "denies every avo_* action" do
      expect(subject.avo_index?).to be false
      expect(subject.avo_update?).to be false
    end
  end

  context "with an admin user" do
    let(:user) { admin_user }

    it "grants every avo_* action" do
      expect(subject.avo_index?).to be true
      expect(subject.avo_show?).to be true
      expect(subject.avo_create?).to be true
      expect(subject.avo_new?).to be true
      expect(subject.avo_update?).to be true
      expect(subject.avo_edit?).to be true
      expect(subject.avo_destroy?).to be true
    end
  end

  describe ApplicationPolicy::Scope do
    it "raises NoMethodError when #resolve is not overridden by a subclass" do
      scope = described_class.new(nil, Driver.all)
      expect { scope.resolve }.to raise_error(NoMethodError)
    end
  end
end
