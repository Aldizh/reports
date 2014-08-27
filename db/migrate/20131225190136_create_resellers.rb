class CreateResellers < ActiveRecord::Migration
  def change
    create_table :resellers do |t|
      t.string :name
      t.float :revenue
      t.float :cost
      t.float :margin
      t.integer :minutes
      t.integer :num_calls
      t.integer :asr

      t.timestamps
    end
  end
end
