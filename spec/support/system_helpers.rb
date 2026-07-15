module SystemHelpers
  # `Warden::Test::Helpers#login_as` hits an arity bug with this
  # Devise/Warden version combo (`serialize_from_session` gets called with 5
  # args instead of 2) — driving the real sign-in form avoids it entirely
  # and is arguably more representative of a real user anyway.
  def sign_in_via_form(user, password: "password123")
    # Literal "/" rather than the `root_path` helper — it resolves to Avo's
    # engine-internal root instead of the app's root in some contexts (see
    # docs/progress.md's Phase 8 deviations for the same issue in request specs).
    visit "/"
    if page.has_button?("Sair")
      click_on "Sair"
      # Wait for the logout -> root -> sign-in redirect chain to actually
      # land, rather than firing the next `visit` while it's still
      # in-flight — otherwise the next request can race the session
      # cookie update and land back on an "already signed in" page.
      expect(page).to have_field("user_email")
    else
      visit new_user_session_path
    end

    fill_in "user_email", with: user.email
    fill_in "user_password", with: password
    click_on "Login"
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
