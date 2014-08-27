class AddAsrToWeekTraffics < ActiveRecord::Migration
  def change
    add_column :week_traffics, :asr, :integer
  end
end
