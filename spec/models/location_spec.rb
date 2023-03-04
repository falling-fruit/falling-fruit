require 'spec_helper'

#    t.float    "lat"
#    t.float    "lng"
#    t.string   "author"
#    t.text     "description"
#    t.integer  "season_start"
#    t.integer  "season_stop"
#    t.boolean  "no_season"
#    t.text     "address"
#    t.datetime "created_at",                                                                                    :null => false
#    t.datetime "updated_at",                                                                                    :null => false
#    t.boolean  "unverified",                                                                 :default => false
#    t.integer  "quality_rating"
#    t.integer  "yield_rating"
#    t.integer  "access"
#    t.integer  "import_id"
#    t.string   "photo_url"
#    t.spatial  "location",       :limit => {:srid=>4326, :type=>"point", :geographic=>true}

describe Location do
  before(:each) do
    @attr = {
      :lat => 180.0 * rand,
      :lng => 180.0 * rand,
      :author => 'Anonymous'
    }
  end
  it "should geocode an address" do
    l = Location.new(@attr.merge({:lat => nil, :lng => nil, :address => "2995 Aurora Ave., Boulder, CO, 80303"}))
    l.should be_valid
  end
  it "shouldn't require an address if lat/lng are provided" do
    l = Location.new(@attr.merge({:address => :nil}))
    l.should be_valid
  end
end
