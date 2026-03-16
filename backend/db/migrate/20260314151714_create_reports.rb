class CreateReports < ActiveRecord::Migration[7.2]
  def change
    create_table :reports do |t|
      t.string :report_type
      t.bigint :generated_by_id
      t.jsonb :date_range, default: {}
      t.jsonb :data, default: {}
      t.string :export_format

      t.timestamps
    end

    add_index :reports, :report_type
    add_index :reports, :generated_by_id
  end
end
