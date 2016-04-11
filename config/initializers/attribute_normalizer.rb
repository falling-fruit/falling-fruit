AttributeNormalizer.configure do |config|
  
  # :squeeze Squeezes repeating spaces to single, and repeating new lines to double
  config.normalizers[:squeeze] = lambda do |value, options|
    if value.is_a?(String)
      value.gsub(/[ ]+/, ' ').gsub(/(\n|\r\n){2,}/, "\\1\\1")
    else
      value
    end
  end
  
  # The following normalizers are already included with the +0.3 version of the gem.
  # :blank Will return nil on empty strings
  # :phone Will strip out all non-digit characters and return nil on empty strings
  # :strip Will strip leading and trailing whitespace.
  # :squish Will strip leading and trailing whitespace and convert any interior whitespace to one space each
  config.default_normalizers = :strip, :squeeze, :blank

  # You can enable the attribute normalizers automatically if the specified attributes exist in your column_names. 
  # It will use the default normalizers for each attribute (e.g. config.default_normalizers)
  # config.default_attributes = :name, :title

  # You can add a specific attribute to default_attributes using one or more normalizers:
  # config.add_default_attribute :name, :with => :truncate
end