class CreateInvoiceLineItems < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :item_type, null: false
      t.string :description
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
