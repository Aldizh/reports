class AddNameToWeekTraffics < ActiveRecord::Migration
  def change
    add_column :week_traffics, :name, :string
  end
end
