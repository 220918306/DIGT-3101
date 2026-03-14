class CreateUnits < ActiveRecord::Migration[7.2]
  def change
    create_table :units do |t|
      t.references :property, null: false, foreign_key: true
      t.string :unit_number, null: false
      t.decimal :size, precision: 10, scale: 2
      t.decimal :rental_rate, precision: 10, scale: 2
      t.string :tier, default: "standard"
      t.string :purpose, default: "retail"
      t.string :status, default: "available"
      t.boolean :available, default: true

      t.timestamps
    end

    add_index :units, :status
    add_index :units, :available
    add_index :units, [:property_id, :unit_number], unique: true
  end
end
