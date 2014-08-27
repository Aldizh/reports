class CreateCustomers < ActiveRecord::Migration
  def change
    create_table :customers do |t|
      t.string :name
      t.float :revenue
      t.float :cost
      t.float :margin
      t.integer :minutes

      t.timestamps
    end
  end
end
