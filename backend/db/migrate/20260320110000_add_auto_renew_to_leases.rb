class AddAutoRenewToLeases < ActiveRecord::Migration[7.2]
  def change
    add_column :leases, :auto_renew, :boolean, default: false, null: false
  end
end
