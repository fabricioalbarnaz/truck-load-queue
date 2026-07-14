require "rails_helper"

RSpec.describe VisitPolicy do
  subject { described_class }

  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:expedition_user) { create(:user).tap { |u| u.roles << create(:role, :expedition_operator) } }
  let(:queue_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }

  permissions :index?, :check_in? do
    it "grants access to a registration operator" do
      expect(subject).to permit(registration_user, Visit)
    end

    it "grants access to admin" do
      expect(subject).to permit(admin_user, Visit)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, Visit)
    end

    it "denies access to unauthenticated users" do
      expect(subject).not_to permit(nil, Visit)
    end
  end

  permissions :issue_order? do
    it "grants access to an expedition operator" do
      expect(subject).to permit(expedition_user, Visit)
    end

    it "grants access to admin" do
      expect(subject).to permit(admin_user, Visit)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, Visit)
      expect(subject).not_to permit(registration_user, Visit)
    end

    it "denies access to unauthenticated users" do
      expect(subject).not_to permit(nil, Visit)
    end
  end

  permissions :finish? do
    it "grants access to a queue operator" do
      expect(subject).to permit(queue_user, Visit)
    end

    it "grants access to admin" do
      expect(subject).to permit(admin_user, Visit)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(registration_user, Visit)
      expect(subject).not_to permit(expedition_user, Visit)
    end

    it "denies access to unauthenticated users" do
      expect(subject).not_to permit(nil, Visit)
    end
  end
end
