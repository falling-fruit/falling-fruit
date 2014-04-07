module BitmaskStuff

  def mask_to_array(mask,options)
    options.each_with_index.collect{ |v,i| (mask & 1<<i) > 0 ? v : nil }.compact
  end
  module_function :mask_to_array

  def array_to_mask(values,options)
    r = 0
    options.each_with_index.each{ |v,i| r = r | 1<<i unless values.index(v).nil? }
    r
  end
  module_function :array_to_mask

end