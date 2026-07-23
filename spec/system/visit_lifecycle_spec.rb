require "rails_helper"

RSpec.describe "Visit lifecycle with live public queue updates", type: :system do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:expedition_user) { create(:user).tap { |u| u.roles << create(:role, :expedition_operator) } }
  let(:queue_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:driver) { create(:driver) }
  let(:truck) { create(:truck) }

  it "flows from check-in through finished, reflected live on the public screen" do
    driver
    truck

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

    sign_in_via_form(expedition_user)
    visit expedition_visits_path
    click_on "Emitir ordem"
    expect(page).to have_content("Ordem de carregamento emitida")

    Capybara.using_session(:public) do
      expect(page).to have_content(driver.name, wait: 10)
      expect(page).to have_content(truck.plate, wait: 10)
    end

    sign_in_via_form(queue_user)
    visit queue_visits_path
    click_on "Finalizar carregamento"
    expect(page).to have_content("Carregamento finalizado")

    Capybara.using_session(:public) do
      expect(page).to have_content("Nenhum caminhão carregando", wait: 10)
    end
  end
end
