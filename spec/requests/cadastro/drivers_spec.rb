require "rails_helper"

RSpec.describe "Cadastro::Drivers", type: :request do
  let(:cadastro_user) { create(:user).tap { |u| u.roles << create(:role, :cadastro) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :fila) } }
  let(:driver) { create(:driver) }

  describe "GET /cadastro/drivers" do
    it "redirects unauthenticated users" do
      get cadastro_drivers_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the cadastro/admin role" do
      sign_in other_user
      get cadastro_drivers_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a cadastro operator" do
      sign_in cadastro_user
      get cadastro_drivers_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /cadastro/drivers" do
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

    it "creates a driver for a cadastro operator" do
      sign_in cadastro_user
      expect {
        post cadastro_drivers_path, params: valid_params
      }.to change(Driver, :count).by(1)
      expect(response).to redirect_to(cadastro_driver_path(Driver.last))
    end

    it "redirects users without the cadastro/admin role without creating a driver" do
      sign_in other_user
      expect {
        post cadastro_drivers_path, params: valid_params
      }.not_to change(Driver, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /cadastro/drivers/:id" do
    it "destroys the driver for a cadastro operator" do
      driver_to_destroy = driver
      sign_in cadastro_user
      expect {
        delete cadastro_driver_path(driver_to_destroy)
      }.to change(Driver, :count).by(-1)
    end
  end
end
