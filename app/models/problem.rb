class Problem < ActiveRecord::Base
  belongs_to :reporter, class_name: "User"
  belongs_to :responder, class_name: "User"
  belongs_to :location
  attr_accessible :comment, :problem_code, :reporter_id, :resolution_code, :responder_id,
                  :response, :reporter, :responder, :id, :location_id, :name, :email

  normalize_attributes *character_column_symbols
  validates :problem_code, :numericality => { :only_integer => true }, :allow_nil => false
  validates :email, presence: true

  Codes = ["Location is spam",
           "Location does not exist",
           "Location is a duplicate",
           "Inappropriate review photo",
           "Inappropriate review comment",
           "Other (explain below)"]
  ShortCodes = ["Spam","Nonexistent","Duplicate","Photo","Comment","Other"]
  Resolutions = ["Made no changes", "Edited the location", "Deleted the location", "Deleted the photo", "Deleted the review"]
end