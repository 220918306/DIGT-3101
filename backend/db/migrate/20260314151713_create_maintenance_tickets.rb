class CreateMaintenanceTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :maintenance_tickets do |t|
      t.references :lease, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.references :unit, null: false, foreign_key: true
      t.bigint :assigned_to_id
      t.string :priority, default: "routine"
      t.string :status, default: "open"
      t.text :description
      t.boolean :is_tenant_caused, default: false
      t.decimal :billing_amount, precision: 10, scale: 2
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :maintenance_tickets, :priority
    add_index :maintenance_tickets, :status
    add_index :maintenance_tickets, :assigned_to_id
  end
end
