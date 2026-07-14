require "rails_helper"

RSpec.describe "Public::Queue", type: :request do
  describe "GET /public/queue" do
    it "is accessible without authentication" do
      get public_queue_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the currently loading visit and the queue" do
      loading_visit = create(:visit, :loading)
      queued_visit = create(:visit, :queued)

      get public_queue_path

      expect(response.body).to include(loading_visit.driver.name)
      expect(response.body).to include(queued_visit.driver.name)
    end
  end
end
