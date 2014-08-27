class AddAsrToCustomers < ActiveRecord::Migration
  def change
    add_column :customers, :asr, :integer
  end
end
