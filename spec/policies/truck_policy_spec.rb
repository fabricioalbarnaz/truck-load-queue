require "rails_helper"

RSpec.describe TruckPolicy do
  subject { described_class }

  let(:cadastro_user) { create(:user).tap { |u| u.roles << create(:role, :cadastro) } }
  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :fila) } }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it "grants access to cadastro" do
      expect(subject).to permit(cadastro_user, Truck)
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
end
