require "rails_helper"

RSpec.describe "Registration::Trucks", type: :request do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:truck) { create(:truck) }

  describe "GET /registration/trucks" do
    it "redirects unauthenticated users" do
      get registration_trucks_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the registration_operator/admin role" do
      sign_in other_user
      get registration_trucks_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a registration operator" do
      sign_in registration_user
      get registration_trucks_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /registration/trucks" do
    let(:valid_params) do
      { truck: { plate: "xyz1234", model: "Volvo FH 540", capacity: 30, active: true } }
    end

    it "creates a truck for a registration operator" do
      sign_in registration_user
      expect {
        post registration_trucks_path, params: valid_params
      }.to change(Truck, :count).by(1)
      expect(Truck.last.plate).to eq("XYZ1234")
      expect(response).to redirect_to(registration_truck_path(Truck.last))
    end

    it "redirects users without the registration_operator/admin role without creating a truck" do
      sign_in other_user
      expect {
        post registration_trucks_path, params: valid_params
      }.not_to change(Truck, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /registration/trucks/:id" do
    it "destroys the truck for a registration operator" do
      truck_to_destroy = truck
      sign_in registration_user
      expect {
        delete registration_truck_path(truck_to_destroy)
      }.to change(Truck, :count).by(-1)
    end
  end
end
