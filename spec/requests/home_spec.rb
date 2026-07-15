require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "redirects unauthenticated users to sign in" do
      get root_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the signed-in user's name, email, and roles" do
      user = create(:user).tap { |u| u.roles << create(:role, :registration_operator) }
      sign_in user

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.name)
      expect(response.body).to include(user.email)
    end
  end
end
