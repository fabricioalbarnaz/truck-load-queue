require "rails_helper"

RSpec.describe "Registration::Visits", type: :request do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:driver) { create(:driver) }
  let(:truck) { create(:truck) }

  let(:new_driver_params) do
    { name: "Novo Motorista", cpf: CPF.generate, phone: "+5511988887777", notification_channel: "sms" }
  end
  let(:new_truck_params) { { plate: "NEW1234", model: "Volvo FH 540", capacity: 30 } }

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
    it "checks in with a brand-new driver and truck" do
      sign_in registration_user

      expect {
        post registration_visits_path,
          params: { visit: { driver: new_driver_params, truck: new_truck_params } }
      }.to change(Visit, :count).by(1)
        .and change(Driver, :count).by(1)
        .and change(Truck, :count).by(1)

      expect(response).to redirect_to(registration_visits_path)
      expect(Visit.last).to be_in_yard
    end

    it "redirects users without the registration_operator/admin role without checking in" do
      sign_in other_user
      expect {
        post registration_visits_path,
          params: { visit: { driver: new_driver_params, truck: new_truck_params } }
      }.not_to change(Visit, :count)
      expect(response).to redirect_to(root_path)
    end

    it "reuses an existing driver found by cpf, ignoring the other submitted fields" do
      sign_in registration_user
      driver_cpf = driver.cpf
      driver_id = driver.id

      expect {
        post registration_visits_path,
          params: {
            visit: {
              driver: { cpf: driver_cpf, name: "Nome Diferente", phone: "+5511900000000" },
              truck: new_truck_params
            }
          }
      }.to change(Visit, :count).by(1)

      expect(Driver.count).to eq(1)
      expect(Visit.last.driver_id).to eq(driver_id)
      expect(driver.reload.name).not_to eq("Nome Diferente")
    end

    it "reuses an existing truck found by plate, ignoring the other submitted fields" do
      sign_in registration_user
      truck_plate = truck.plate
      truck_id = truck.id

      expect {
        post registration_visits_path,
          params: {
            visit: {
              driver: new_driver_params,
              truck: { plate: truck_plate, model: "Modelo Diferente", capacity: 1 }
            }
          }
      }.to change(Visit, :count).by(1)

      expect(Truck.count).to eq(1)
      expect(Visit.last.truck_id).to eq(truck_id)
      expect(truck.reload.model).not_to eq("Modelo Diferente")
    end

    it "matches an existing driver's cpf regardless of punctuation" do
      sign_in registration_user
      driver_cpf_digits = driver.cpf
      punctuated = "#{driver_cpf_digits[0..2]}.#{driver_cpf_digits[3..5]}.#{driver_cpf_digits[6..8]}-#{driver_cpf_digits[9..10]}"
      driver_id = driver.id

      post registration_visits_path,
        params: { visit: { driver: { cpf: punctuated }, truck: new_truck_params } }

      expect(Driver.count).to eq(1)
      expect(Visit.last.driver_id).to eq(driver_id)
    end

    it "blocks a duplicate check-in for a driver already in the yard" do
      sign_in registration_user
      create(:visit, driver: driver)
      driver_cpf = driver.cpf

      expect {
        post registration_visits_path,
          params: { visit: { driver: { cpf: driver_cpf }, truck: new_truck_params } }
      }.not_to change(Visit, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create anything when the existing driver is paired with an invalid new truck" do
      sign_in registration_user
      driver_cpf = driver.cpf

      expect {
        post registration_visits_path,
          params: { visit: { driver: { cpf: driver_cpf }, truck: { plate: "" } } }
      }.not_to change(Visit, :count)

      expect(Truck.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Placa")
    end

    it "renders presence errors when no driver data is provided at all" do
      sign_in registration_user

      expect {
        post registration_visits_path, params: { visit: { truck: new_truck_params } }
      }.not_to change(Visit, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nome")
    end
  end
end
