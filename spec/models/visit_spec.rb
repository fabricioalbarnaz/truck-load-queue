require "rails_helper"

RSpec.describe Visit, type: :model do
  subject { build(:visit) }

  it { is_expected.to belong_to(:driver) }
  it { is_expected.to belong_to(:truck) }
  it { is_expected.to belong_to(:checked_in_by).class_name("User") }
  it { is_expected.to belong_to(:order_issued_by).class_name("User").optional }
  it { is_expected.to belong_to(:finished_by).class_name("User").optional }
  it { is_expected.to validate_presence_of(:entered_yard_at) }

  it {
    is_expected.to define_enum_for(:status)
      .with_values(in_yard: "in_yard", queued: "queued", loading: "loading", finished: "finished")
      .backed_by_column_of_type(:string)
  }

  describe "one active visit per driver/truck" do
    it "is invalid when the driver already has an in_yard visit" do
      existing = create(:visit)
      other_visit = build(:visit, driver: existing.driver)

      expect(other_visit).not_to be_valid
      expect(other_visit.errors[:driver]).to be_present
    end

    it "is invalid when the truck already has an in_yard visit" do
      existing = create(:visit)
      other_visit = build(:visit, truck: existing.truck)

      expect(other_visit).not_to be_valid
      expect(other_visit.errors[:truck]).to be_present
    end

    it "allows a new visit once the previous one for the same driver/truck is finished" do
      finished = create(:visit, :finished)
      other_visit = build(:visit, driver: finished.driver, truck: finished.truck)

      expect(other_visit).to be_valid
    end
  end

  describe ".active_queue" do
    it "returns queued and loading visits ordered by order_issued_at" do
      later = create(:visit, :queued, order_issued_at: 2.minutes.ago)
      earlier = create(:visit, :loading, order_issued_at: 5.minutes.ago)
      create(:visit) # in_yard, not part of the active queue

      expect(Visit.active_queue).to eq([ earlier, later ])
    end
  end

  describe "#queue_position" do
    it "is 0 for a visit that is loading" do
      visit = create(:visit, :loading)
      expect(visit.queue_position).to eq(0)
    end

    it "reflects FIFO order among queued visits" do
      first = create(:visit, :queued, order_issued_at: 3.minutes.ago)
      second = create(:visit, :queued, order_issued_at: 2.minutes.ago)
      third = create(:visit, :queued, order_issued_at: 1.minute.ago)

      expect(first.queue_position).to eq(1)
      expect(second.queue_position).to eq(2)
      expect(third.queue_position).to eq(3)
    end
  end

  describe "public queue broadcast" do
    it "does not broadcast on check-in (in_yard creation)" do
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)
      create(:visit)
    end

    it "broadcasts to public_queue when a visit becomes queued" do
      visit = create(:visit)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("public_queue", hash_including(target: "public_queue", partial: "public/queue/board"))

      visit.update(status: :queued, order_issued_at: Time.current)
    end

    it "broadcasts when a visit finishes" do
      visit = create(:visit, :loading)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("public_queue", hash_including(target: "public_queue"))

      visit.update(status: :finished, finished_at: Time.current)
    end
  end
end
