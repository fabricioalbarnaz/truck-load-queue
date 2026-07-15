require "rails_helper"

RSpec.describe "Admin (Avo)", type: :request do
  let(:admin) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:operator) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  describe "GET /admin" do
    it "redirects unauthenticated users to the app root" do
      get "/admin"
      expect(response).to redirect_to("/")
    end

    it "redirects non-admin users to the app root" do
      sign_in operator
      get "/admin"
      expect(response).to redirect_to("/")
    end

    it "is accessible to an admin (redirects to Avo's default resource, not the app root)" do
      sign_in admin
      get "/admin"
      expect(response).to have_http_status(:found)
      expect(response.location).not_to eq("http://www.example.com/")
    end
  end

  describe "role assignment via the UserRole resource" do
    it "lets an admin create a user and assign a role" do
      sign_in admin

      expect {
        post "/admin/resources/users", params: {
          user: {
            name: "New Operator",
            email: "new_operator@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.to change(User, :count).by(1)

      new_user = User.find_by(email: "new_operator@example.com")
      registration_role = create(:role, :registration_operator)

      expect {
        post "/admin/resources/user_roles", params: {
          user_role: { user_id: new_user.id, role_id: registration_role.id }
        }
      }.to change(UserRole, :count).by(1)

      expect(new_user.reload.role?(:registration_operator)).to be true
    end

    it "denies a non-admin from creating a user" do
      sign_in operator

      expect {
        post "/admin/resources/users", params: {
          user: { name: "Nope", email: "nope@example.com", password: "password123", password_confirmation: "password123" }
        }
      }.not_to change(User, :count)
    end
  end
end
