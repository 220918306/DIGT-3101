class AddCancelledAtToApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :applications, :cancelled_at, :datetime
  end
end
