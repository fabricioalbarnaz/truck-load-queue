require "rails_helper"

RSpec.describe DriverPolicy do
  subject { described_class }

  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it "grants access to a registration operator" do
      expect(subject).to permit(registration_user, Driver)
    end

    it "grants access to admin" do
      expect(subject).to permit(admin_user, Driver)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, Driver)
    end

    it "denies access to unauthenticated users" do
      expect(subject).not_to permit(nil, Driver)
    end
  end
end
