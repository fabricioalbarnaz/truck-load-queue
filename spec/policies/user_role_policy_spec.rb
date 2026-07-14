require "rails_helper"

RSpec.describe UserRolePolicy do
  subject { described_class }

  let(:admin_user) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  permissions :avo_index?, :avo_show?, :avo_create?, :avo_update?, :avo_destroy? do
    it "grants access to admin" do
      expect(subject).to permit(admin_user, UserRole)
    end

    it "denies access to other roles" do
      expect(subject).not_to permit(other_user, UserRole)
    end
  end
end
