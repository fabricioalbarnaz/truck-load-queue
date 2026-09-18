require "rails_helper"

RSpec.describe "Visit lifecycle with live public queue updates", type: :system do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:expedition_user) { create(:user).tap { |u| u.roles << create(:role, :expedition_operator) } }
  let(:queue_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:driver) { create(:driver, name: "Motorista Alfa") }
  let(:truck) { create(:truck) }
  let(:next_driver) { create(:driver, name: "Motorista Beta") }
  let(:next_truck) { create(:truck) }

  it "flows from check-in through finished, reflected live on the public screen" do
    driver
    truck
    next_driver
    next_truck

    Capybara.using_session(:public) do
      visit public_queue_path
      expect(page).to have_content("Nenhum caminhão carregando")
    end

    sign_in_via_form(registration_user)
    visit registration_visits_path
    fill_in "visit_driver_cpf", with: driver.cpf
    fill_in "visit_truck_plate", with: truck.plate
    click_on "Registrar check-in"
    expect(page).to have_content(driver.name)

    fill_in "visit_driver_cpf", with: next_driver.cpf
    fill_in "visit_truck_plate", with: next_truck.plate
    click_on "Registrar check-in"
    expect(page).to have_content(next_driver.name)

    sign_in_via_form(expedition_user)
    visit expedition_visits_path
    within("tr", text: driver.name) do
      fill_in "visit_order_number", with: "OC-123"
      click_on "Emitir ordem"
    end
    expect(page).to have_content("Ordem de carregamento emitida")

    Capybara.using_session(:public) do
      expect(page).to have_content(driver.name, wait: 10)
      expect(page).to have_content(truck.plate, wait: 10)
    end

    visit expedition_visits_path
    within("tr", text: next_driver.name) do
      fill_in "visit_order_number", with: "OC-456"
      click_on "Emitir ordem"
    end
    expect(page).to have_content("Ordem de carregamento emitida")

    Capybara.using_session(:public) do
      expect(page).to have_content(/prepare-se/i, wait: 10)
      expect(page).to have_content(next_driver.name, wait: 10)
    end

    sign_in_via_form(queue_user)
    visit queue_visits_path
    click_on "Finalizar carregamento"
    expect(page).to have_content("Carregamento finalizado")

    Capybara.using_session(:public) do
      expect(page).to have_content(next_driver.name, wait: 10)
      expect(page).to have_content("Nenhum caminhão se preparando no momento.", wait: 10)
    end
  end
end
