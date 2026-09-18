class AddGettingReadyAtToVisits < ActiveRecord::Migration[8.0]
  def change
    add_column :visits, :getting_ready_at, :datetime
  end
end
