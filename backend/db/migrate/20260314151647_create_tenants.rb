class CreateTenants < ActiveRecord::Migration[7.2]
  def change
    create_table :tenants do |t|
      t.references :user, null: false, foreign_key: true
      t.string :phone
      t.string :company_name

      t.timestamps
    end
  end
end
