class ConvertTransportTypeToInteger < ActiveRecord::Migration
  def change
    add_column :routes, :temp, :integer, :default => nil
    Route.where(:transport_type => "Walking").each{ |r|
      r.temp = 0
      r.save
    }
    Route.where(:transport_type => "Bicycling").each{ |r|
      r.temp = 1
      r.save
    }
    Route.where(:transport_type => "Driving").each{ |r|
      r.temp = 2
      r.save
    }
    remove_column :routes, :transport_type
    rename_column :routes, :temp, :transport_type
    change_column :routes, :transport_type, :integer, :default => 0
  end
end
