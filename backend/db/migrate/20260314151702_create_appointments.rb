class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :unit, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.datetime :scheduled_time, null: false
      t.string :status, default: "pending"

      t.timestamps
    end

    add_index :appointments, [:unit_id, :scheduled_time]
    add_index :appointments, [:tenant_id, :scheduled_time]
  end
end
