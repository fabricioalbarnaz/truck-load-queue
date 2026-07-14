require "rails_helper"

RSpec.describe RolePolicy do
  subject { described_class }

  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  permissions :avo_index?, :avo_show?, :avo_update? do
    it "grants access to admin" do
      expect(subject).to permit(admin_user, Role)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, Role)
    end
  end

  permissions :avo_create?, :avo_destroy? do
    it "denies access even to admin, since Role::KEYS is fixed reference data" do
      expect(subject).not_to permit(admin_user, Role)
    end
  end
end
