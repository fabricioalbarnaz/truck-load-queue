require "rails_helper"

RSpec.describe "Registration::Drivers", type: :request do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:driver) { create(:driver) }

  describe "GET /registration/drivers" do
    it "redirects unauthenticated users" do
      get registration_drivers_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the registration_operator/admin role" do
      sign_in other_user
      get registration_drivers_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a registration operator" do
      sign_in registration_user
      get registration_drivers_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /registration/drivers" do
    let(:valid_params) do
      {
        driver: {
          name: "João da Silva",
          cpf: CPF.generate,
          phone: "+5511988887777",
          notification_channel: "sms",
          active: true
        }
      }
    end

    it "creates a driver for a registration operator" do
      sign_in registration_user
      expect {
        post registration_drivers_path, params: valid_params
      }.to change(Driver, :count).by(1)
      expect(response).to redirect_to(registration_driver_path(Driver.last))
    end

    it "redirects users without the registration_operator/admin role without creating a driver" do
      sign_in other_user
      expect {
        post registration_drivers_path, params: valid_params
      }.not_to change(Driver, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /registration/drivers/:id" do
    it "destroys the driver for a registration operator" do
      driver_to_destroy = driver
      sign_in registration_user
      expect {
        delete registration_driver_path(driver_to_destroy)
      }.to change(Driver, :count).by(-1)
    end
  end

  describe "GET /registration/drivers/lookup" do
    it "redirects unauthenticated users" do
      get lookup_registration_drivers_path, params: { cpf: driver.cpf }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the registration_operator/admin role" do
      sign_in other_user
      get lookup_registration_drivers_path, params: { cpf: driver.cpf }
      expect(response).to redirect_to(root_path)
    end

    it "returns the driver's data when the cpf matches" do
      sign_in registration_user
      get lookup_registration_drivers_path, params: { cpf: driver.cpf }

      json = response.parsed_body
      expect(json["found"]).to be true
      expect(json["record"]).to eq(
        "name" => driver.name, "phone" => driver.phone, "notification_channel" => driver.notification_channel
      )
    end

    it "matches regardless of cpf punctuation" do
      sign_in registration_user
      digits = driver.cpf
      punctuated = "#{digits[0..2]}.#{digits[3..5]}.#{digits[6..8]}-#{digits[9..10]}"

      get lookup_registration_drivers_path, params: { cpf: punctuated }

      expect(response.parsed_body["found"]).to be true
    end

    it "returns not found when no driver matches" do
      sign_in registration_user
      get lookup_registration_drivers_path, params: { cpf: "00000000000" }

      expect(response.parsed_body["found"]).to be false
    end
  end
end
