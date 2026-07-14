require "rails_helper"

RSpec.describe "Queue::Visits", type: :request do
  let(:queue_user) { create(:user).tap { |u| u.roles << create(:role, :queue_operator) } }
  let(:other_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }

  describe "GET /queue/visits" do
    it "redirects unauthenticated users" do
      get queue_visits_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users without the queue_operator/admin role" do
      sign_in other_user
      get queue_visits_path
      expect(response).to redirect_to(root_path)
    end

    it "is successful for a queue operator" do
      sign_in queue_user
      get queue_visits_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /queue/visits/:id/finish" do
    it "finishes the loading visit and promotes the next queued one" do
      visit = create(:visit, :loading)
      next_up = create(:visit, :queued, order_issued_at: 1.hour.ago)
      sign_in queue_user

      patch finish_queue_visit_path(visit)

      expect(response).to redirect_to(queue_visits_path)
      expect(visit.reload).to be_finished
      expect(visit.finished_by).to eq(queue_user)
      expect(next_up.reload).to be_loading
    end

    it "redirects users without the queue_operator/admin role without finishing the visit" do
      visit = create(:visit, :loading)
      sign_in other_user

      patch finish_queue_visit_path(visit)

      expect(response).to redirect_to(root_path)
      expect(visit.reload).to be_loading
    end
  end
end
