class AddHikcentralSyncedAtToTrucks < ActiveRecord::Migration[8.0]
  def change
    add_column :trucks, :hikcentral_synced_at, :datetime
  end
end
