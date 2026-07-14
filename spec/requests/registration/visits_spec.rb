require "rails_helper"

RSpec.describe "Registration::Visits", type: :request do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:driver) { create(:driver) }
  let(:truck) { create(:truck) }

  describe "GET /registration/visits" do
    it "redirects unauthenticated users" do
      get registration_visits_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the registration_operator/admin role" do
      sign_in other_user
      get registration_visits_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a registration operator" do
      sign_in registration_user
      get registration_visits_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /registration/visits" do
    it "checks in the driver/truck for a registration operator" do
      sign_in registration_user
      expect {
        post registration_visits_path, params: { visit: { driver_id: driver.id, truck_id: truck.id } }
      }.to change(Visit, :count).by(1)

      expect(response).to redirect_to(registration_visits_path)
      expect(Visit.last).to be_in_yard
    end

    it "redirects users without the registration_operator/admin role without checking in" do
      sign_in other_user
      expect {
        post registration_visits_path, params: { visit: { driver_id: driver.id, truck_id: truck.id } }
      }.not_to change(Visit, :count)
      expect(response).to redirect_to(root_path)
    end

    it "blocks a duplicate check-in for a driver already in the yard" do
      sign_in registration_user
      create(:visit, driver: driver)

      expect {
        post registration_visits_path, params: { visit: { driver_id: driver.id, truck_id: truck.id } }
      }.not_to change(Visit, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
