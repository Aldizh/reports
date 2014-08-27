class CreateWeekTraffics < ActiveRecord::Migration
  def change
    create_table :week_traffics do |t|
      t.string :calldate
      t.float :revenue
      t.float :cost
      t.float :margin
      t.integer :minutes
      t.integer :calls

      t.timestamps
    end
  end
end
