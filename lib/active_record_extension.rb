module ActiveRecordExtension

  extend ActiveSupport::Concern

  # Static(class) methods
  module ClassMethods
    def column_symbols
      self.columns.collect{ |c| c.name.to_sym }
    end
    def character_column_symbols
      self.columns.select{ |c| [:text,:string].include?(c.type) }.collect{ |c| c.name.to_sym }
    end
    def text_column_symbols
      self.columns.select{ |c| c.type == :text }.collect{ |c| c.name.to_sym }
    end
  end
end

# include the extension 
ActiveRecord::Base.send(:include, ActiveRecordExtension)