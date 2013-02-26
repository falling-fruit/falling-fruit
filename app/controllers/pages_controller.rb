class PagesController < ApplicationController
  def data
    @types = ActiveRecord::Base.connection.execute("SELECT t.id, t.scientific_name, t.usda_symbol, t.name, count(*) FROM types t, locations_types lt WHERE lt.type_id=t.id GROUP BY t.id, t.scientific_name, t.usda_symbol, t.name ORDER BY t.name")
  end
end
