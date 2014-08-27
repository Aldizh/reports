class AddNumCallsToCustomers < ActiveRecord::Migration
  def change
    add_column :customers, :num_calls, :integer
  end
end
