require "rails_helper"

RSpec.describe "Check-in CPF/plate lookup autofill", type: :system do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:driver) { create(:driver) }
  let(:truck) { create(:truck) }

  it "autofills driver and truck fields when an existing cpf/plate is entered" do
    driver
    truck

    sign_in_via_form(registration_user)
    visit registration_visits_path

    fill_in "visit_driver_cpf", with: driver.cpf
    find_field("visit_driver_cpf").send_keys(:tab)
    expect(page).to have_field("visit_driver_name", with: driver.name)
    expect(page).to have_field("visit_driver_phone", with: driver.phone)

    fill_in "visit_truck_plate", with: truck.plate
    find_field("visit_truck_plate").send_keys(:tab)
    expect(page).to have_field("visit_truck_model", with: truck.model)
    expect(page).to have_field("visit_truck_capacity", with: truck.capacity.to_s)

    click_on "Registrar check-in"

    expect(page).to have_content(driver.name)
    expect(page).to have_content(truck.plate)
  end

  it "leaves the other fields untouched when the cpf doesn't match any driver" do
    sign_in_via_form(registration_user)
    visit registration_visits_path

    fill_in "visit_driver_cpf", with: CPF.generate
    find_field("visit_driver_cpf").send_keys(:tab)

    expect(page).to have_field("visit_driver_name", with: "")
  end

  it "disables every field and the submit button, and shows a spinner, while the lookup is in flight" do
    driver

    sign_in_via_form(registration_user)
    visit registration_visits_path

    # Artificially delay fetch (test-only, via the browser's own window object) so the
    # loading state is observable instead of racing a same-machine round-trip.
    page.execute_script(<<~JS)
      const originalFetch = window.fetch
      window.fetch = (...args) => new Promise((resolve) => {
        setTimeout(() => resolve(originalFetch(...args)), 500)
      })
    JS

    expect(page).to have_button("Registrar check-in", disabled: false)

    fill_in "visit_driver_cpf", with: driver.cpf
    find_field("visit_driver_cpf").send_keys(:tab)

    expect(page).to have_button("Registrar check-in", disabled: true)
    expect(page).to have_css('[data-lookup-target="spinner"]', visible: :visible)
    expect(page).to have_field("visit_driver_cpf", disabled: true)
    expect(page).to have_field("visit_driver_name", disabled: true)
    expect(page).to have_field("visit_truck_plate", disabled: true)

    expect(page).to have_field("visit_driver_name", with: driver.name, disabled: false)
    expect(page).to have_button("Registrar check-in", disabled: false)
    expect(page).to have_field("visit_driver_cpf", disabled: false)
    expect(page).to have_field("visit_truck_plate", disabled: false)
    expect(page).to have_css('[data-lookup-target="spinner"]', visible: :hidden)
  end
end
