class CreateLetters < ActiveRecord::Migration[7.2]
  def change
    create_table :letters do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :lease, null: false, foreign_key: true
      t.string :letter_type, null: false, default: "lease_agreement"
      t.string :status, null: false, default: "sent"
      t.string :subject, null: false
      t.text :body, null: false
      t.datetime :sent_at
      t.datetime :signed_at

      t.timestamps
    end

    add_index :letters, :status
    add_index :letters, [:tenant_id, :lease_id, :letter_type]
  end
end
