require "rails_helper"

RSpec.describe "Cadastro::Trucks", type: :request do
  let(:cadastro_user) { create(:user).tap { |u| u.roles << create(:role, :cadastro) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :fila) } }
  let(:truck) { create(:truck) }

  describe "GET /cadastro/trucks" do
    it "redirects unauthenticated users" do
      get cadastro_trucks_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the cadastro/admin role" do
      sign_in other_user
      get cadastro_trucks_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a cadastro operator" do
      sign_in cadastro_user
      get cadastro_trucks_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /cadastro/trucks" do
    let(:valid_params) do
      { truck: { plate: "xyz1234", model: "Volvo FH 540", capacity: 30, active: true } }
    end

    it "creates a truck for a cadastro operator" do
      sign_in cadastro_user
      expect {
        post cadastro_trucks_path, params: valid_params
      }.to change(Truck, :count).by(1)
      expect(Truck.last.plate).to eq("XYZ1234")
      expect(response).to redirect_to(cadastro_truck_path(Truck.last))
    end

    it "redirects users without the cadastro/admin role without creating a truck" do
      sign_in other_user
      expect {
        post cadastro_trucks_path, params: valid_params
      }.not_to change(Truck, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /cadastro/trucks/:id" do
    it "destroys the truck for a cadastro operator" do
      truck_to_destroy = truck
      sign_in cadastro_user
      expect {
        delete cadastro_truck_path(truck_to_destroy)
      }.to change(Truck, :count).by(-1)
    end
  end
end
