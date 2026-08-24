class AddOrderNumberToVisits < ActiveRecord::Migration[8.0]
  def change
    add_column :visits, :order_number, :string
  end
end
