class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :payment_method, default: "online"
      t.string :transaction_id
      t.string :status, default: "approved"
      t.boolean :processed, default: false

      t.timestamps
    end

    add_index :payments, :transaction_id, unique: true
    add_index :payments, :status
  end
end
