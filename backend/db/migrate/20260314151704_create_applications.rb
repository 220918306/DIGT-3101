class CreateApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :applications do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :unit, null: false, foreign_key: true
      t.string :status, default: "pending"
      t.jsonb :application_data, default: {}
      t.text :employment_info
      t.date :application_date
      t.datetime :approved_at
      t.text :rejection_reason
      t.bigint :reviewed_by_id
      t.foreign_key :users, column: :reviewed_by_id

      t.timestamps
    end

    add_index :applications, :status
    add_index :applications, :reviewed_by_id
  end
end
