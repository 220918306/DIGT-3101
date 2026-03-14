class CreateUtilityConsumptions < ActiveRecord::Migration[7.2]
  def change
    create_table :utility_consumptions do |t|
      t.references :lease, null: false, foreign_key: true
      t.date :billing_period
      t.decimal :electricity_usage, precision: 10, scale: 2, default: 0
      t.decimal :electricity_charge, precision: 10, scale: 2, default: 0
      t.decimal :water_usage, precision: 10, scale: 2, default: 0
      t.decimal :water_charge, precision: 10, scale: 2, default: 0
      t.decimal :waste_charge, precision: 10, scale: 2, default: 0

      t.timestamps
    end

    add_index :utility_consumptions, [:lease_id, :billing_period], unique: true
  end
end
