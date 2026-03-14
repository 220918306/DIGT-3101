class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      t.references :lease, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_paid, precision: 10, scale: 2, default: 0
      t.string :status, default: "unpaid"
      t.date :due_date, null: false
      t.date :billing_month
      t.integer :reminder_count, default: 0
      t.datetime :last_reminder_at

      t.timestamps
    end

    add_index :invoices, :status
    add_index :invoices, [:tenant_id, :status]
    add_index :invoices, [:lease_id, :billing_month]
  end
end
