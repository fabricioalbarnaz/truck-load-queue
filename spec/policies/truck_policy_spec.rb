require "rails_helper"

RSpec.describe TruckPolicy do
  subject { described_class }

  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it "grants access to a registration operator" do
      expect(subject).to permit(registration_user, Truck)
    end

    it "grants access to admin" do
      expect(subject).to permit(admin_user, Truck)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, Truck)
    end

    it "denies access to unauthenticated users" do
      expect(subject).not_to permit(nil, Truck)
    end
  end

  permissions :avo_index?, :avo_show?, :avo_create?, :avo_update?, :avo_destroy? do
    it "grants access to admin only, not a registration operator" do
      expect(subject).to permit(admin_user, Truck)
      expect(subject).not_to permit(registration_user, Truck)
    end
  end
end
