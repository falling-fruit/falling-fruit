class Observation < ActiveRecord::Base

  belongs_to :user
  belongs_to :location
  attr_accessible :yield_rating, :quality_rating, :fruiting, :user_id,
    :location_id, :location, :user, :id, :photo, :comment, :author, :observed_on,
    :photo_caption, :destroyed?, :graft

  has_attached_file :photo, :styles => { :medium => "300x300>", :thumb => "100x100>" }, :s3_credentials => File.join(Rails.root, 'config', 's3.yml'),
                    :storage => :s3, :s3_permissions => 'private',:s3_protocol => 'https',
                    :s3_host_name => 's3-us-west-2.amazonaws.com'

  normalize_attributes *character_column_symbols
  validate :not_all_blank
  validates :fruiting, :quality_rating, :yield_rating, :numericality => { :only_integer => true }, :allow_nil => true
  validates_date :observed_on, :allow_nil => true, :on_or_before => lambda { Time.zone.today+1 }
  validates_each :photo_caption do |record,attr,value|
    record.errors.add(attr,'cannot be given without a corresponding photo') if !value.blank? and record.photo_file_name.nil?
  end

  def not_all_blank
    if [observed_on, comment, fruiting, quality_rating, yield_rating, photo_file_name].all? { |x| x.nil? }
      errors[:base] << I18n.translate("observations.empty")
    end
  end

end
