require "rails_helper"

RSpec.describe "Avo admin panel", type: :system do
  let(:admin) { create(:user).tap { |u| u.roles << create(:role, :admin) } }
  let(:operator) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  it "redirects a non-admin away from /admin" do
    sign_in_via_form(operator)
    visit "/admin"
    expect(page).to have_current_path(root_path)
  end

  it "lets an admin create a user, assign a role via UserRole, and that user can log in to their screen" do
    admin
    sign_in_via_form(admin)

    visit "/admin/resources/users/new"
    fill_in "user_name", with: "New Operator"
    fill_in "user_email", with: "new_operator@example.com"
    fill_in "user_password", with: "password123"
    fill_in "user_password_confirmation", with: "password123"
    click_on "Salvar"
    expect(page).to have_content("New Operator")

    new_user = User.find_by(email: "new_operator@example.com")
    registration_role = create(:role, :registration_operator)

    visit "/admin/resources/user_roles/new"
    select "New Operator", from: "user_role_user_id"
    select registration_role.name, from: "user_role_role_id"
    click_on "Salvar"

    expect(new_user.reload.role?(:registration_operator)).to be true

    sign_in_via_form(new_user)
    visit registration_visits_path
    expect(page).to have_current_path(registration_visits_path)
    expect(page).to have_content("Check-in")
  end
end
