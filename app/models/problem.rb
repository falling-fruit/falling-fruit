class Problem < ActiveRecord::Base
  belongs_to :reporter, class_name: "User"
  belongs_to :responder, class_name: "User"
  belongs_to :location
  attr_accessible :comment, :problem_code, :reporter_id, :resolution_code, :responder_id, :response, :reporter, :responder, :id, :location_id, :name, :email

  validates :problem_code, :numericality => { :only_integer => true }, :allow_nil => false

  Codes = ["This Location is SPAM. Please delete.",
           "This Location is wrong or doesn't exist. Please delete.",
           "This Location is a duplicate. Please delete.",
           "Inappropriate Photo. Please remove it.",
           "Inappropriate Comment. Please remove it.",
           "Something else. Explain below"]
  ShortCodes = ["SPAM","DNE","Duplicate","Photo","Comment","Other"]
end
