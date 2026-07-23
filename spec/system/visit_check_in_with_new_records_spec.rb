require "rails_helper"

RSpec.describe "Check-in with inline driver/truck registration", type: :system do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  it "registers a new driver and a new truck and checks them in, in a single submission" do
    sign_in_via_form(registration_user)
    visit registration_visits_path

    fill_in "visit_driver_cpf", with: CPF.generate
    fill_in "visit_driver_name", with: "Carlos Souza"
    fill_in "visit_driver_phone", with: "+5511977776666"
    select "sms", from: "visit_driver_notification_channel"

    fill_in "visit_truck_plate", with: "NEW9999"
    fill_in "visit_truck_model", with: "Scania R450"
    fill_in "visit_truck_capacity", with: "25"

    click_on "Registrar check-in"

    expect(page).to have_content("Carlos Souza")
    expect(page).to have_content("NEW9999")

    driver = Driver.find_by(name: "Carlos Souza")
    truck = Truck.find_by(plate: "NEW9999")
    expect(driver).to be_present
    expect(truck).to be_present
    expect(Visit.last).to have_attributes(driver: driver, truck: truck)

    visit registration_drivers_path
    expect(page).to have_content("Carlos Souza")

    visit registration_trucks_path
    expect(page).to have_content("NEW9999")
  end

  it "shows validation errors without checking in when the new truck plate is blank" do
    sign_in_via_form(registration_user)
    visit registration_visits_path

    fill_in "visit_driver_name", with: "Ana Lima"
    fill_in "visit_driver_cpf", with: CPF.generate
    fill_in "visit_driver_phone", with: "+5511966665555"

    click_on "Registrar check-in"

    expect(page).to have_content("Placa")
    expect(Driver.find_by(name: "Ana Lima")).to be_nil
  end
end
