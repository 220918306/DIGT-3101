class Report < ApplicationRecord
  belongs_to :generated_by, class_name: "User", optional: true

  validates :report_type, presence: true
end
