class CreateLeases < ActiveRecord::Migration[7.2]
  def change
    create_table :leases do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :unit, null: false, foreign_key: true
      t.references :application, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :rent_amount, precision: 10, scale: 2, null: false
      t.string :payment_cycle, default: "monthly"
      t.decimal :discount_rate, precision: 5, scale: 2, default: 0
      t.string :status, default: "active"

      t.timestamps
    end

    add_index :leases, :status
    add_index :leases, [:tenant_id, :status]
  end
end
