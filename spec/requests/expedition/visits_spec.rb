require "rails_helper"

RSpec.describe "Expedition::Visits", type: :request do
  let(:expedition_user) { create(:user).tap { |u| u.roles << create(:role, :expedition_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  describe "GET /expedition/visits" do
    it "redirects unauthenticated users" do
      get expedition_visits_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the expedition_operator/admin role" do
      sign_in other_user
      get expedition_visits_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for an expedition operator" do
      sign_in expedition_user
      get expedition_visits_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /expedition/visits/:id/issue_order" do
    it "sends the visit straight to loading when the queue is empty" do
      visit = create(:visit)
      sign_in expedition_user

      patch issue_order_expedition_visit_path(visit)

      expect(response).to redirect_to(expedition_visits_path)
      expect(visit.reload).to be_loading
      expect(visit.order_issued_by).to eq(expedition_user)
    end

    it "queues the visit when another one is already loading" do
      create(:visit, :loading)
      visit = create(:visit)
      sign_in expedition_user

      patch issue_order_expedition_visit_path(visit)

      expect(visit.reload).to be_queued
    end

    it "redirects users without the expedition_operator/admin role without issuing the order" do
      visit = create(:visit)
      sign_in other_user

      patch issue_order_expedition_visit_path(visit)

      expect(response).to redirect_to(root_path)
      expect(visit.reload).to be_in_yard
    end
  end
end
