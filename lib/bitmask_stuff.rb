module BitmaskStuff

  def mask_to_array(mask,options)
    return [] if mask.nil? or mask == 0
    options.each_with_index.collect{ |v,i| (mask & 1<<i) > 0 ? v : nil }.compact
  end
  module_function :mask_to_array

  def array_to_mask(values,options)
    return 0 if values.nil? or (values.kind_of? Array and values.empty?)
    r = 0
    options.each_with_index.each{ |v,i| r = r | 1<<i unless values.index(v).nil? }
    r
  end
  module_function :array_to_mask

  def full_mask(options)
    array_to_mask(options,options)
  end
  module_function :full_mask

end