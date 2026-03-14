class CreateProperties < ActiveRecord::Migration[7.2]
  def change
    create_table :properties do |t|
      t.string :name, null: false
      t.string :address
      t.string :manager

      t.timestamps
    end
  end
end
