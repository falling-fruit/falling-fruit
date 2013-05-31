# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130531015908) do

  create_table "admins", :force => true do |t|
    t.string   "email",                  :default => "", :null => false
    t.string   "encrypted_password",     :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.boolean  "approved"
  end

  add_index "admins", ["email"], :name => "index_admins_on_email", :unique => true
  add_index "admins", ["reset_password_token"], :name => "index_admins_on_reset_password_token", :unique => true

  create_table "changes", :force => true do |t|
    t.integer  "location_id"
    t.integer  "admin_id"
    t.string   "remote_ip"
    t.text     "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "clusters", :force => true do |t|
    t.string   "method"
    t.boolean  "muni"
    t.float    "grid_size"
    t.integer  "count"
    t.integer  "zoom"
    t.float    "center_lat"
    t.float    "center_lng"
    t.datetime "created_at",                                            :null => false
    t.datetime "updated_at",                                            :null => false
    t.spatial  "grid_point", :limit => {:srid=>4326, :type=>"point"}
    t.spatial  "polygon",    :limit => {:srid=>4326, :type=>"polygon"}
  end

  create_table "imports", :force => true do |t|
    t.string   "url"
    t.string   "name"
    t.text     "comments"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "autoload",   :default => true,  :null => false
    t.boolean  "muni",       :default => false
    t.text     "license"
  end

  create_table "locations", :force => true do |t|
    t.float    "lat"
    t.float    "lng"
    t.string   "author"
    t.text     "description"
    t.integer  "season_start"
    t.integer  "season_stop"
    t.boolean  "no_season"
    t.text     "address"
    t.datetime "created_at",                                                                                    :null => false
    t.datetime "updated_at",                                                                                    :null => false
    t.boolean  "unverified",                                                                 :default => false
    t.integer  "quality_rating"
    t.integer  "yield_rating"
    t.integer  "access"
    t.integer  "import_id"
    t.string   "photo_url"
    t.spatial  "location",       :limit => {:srid=>4326, :type=>"point", :geographic=>true}
    t.string   "client",                                                                     :default => "web"
    t.string   "city"
    t.string   "state"
    t.string   "country"
  end

  add_index "locations", ["location"], :name => "index_locations_on_location", :spatial => true

  create_table "locations_types", :force => true do |t|
    t.integer "location_id"
    t.integer "type_id"
    t.string  "type_other"
  end

  create_table "observations", :force => true do |t|
    t.integer  "location_id"
    t.boolean  "is_fruiting"
    t.text     "comment"
    t.date     "observed_on"
    t.string   "photo_file_name"
    t.string   "photo_content_type"
    t.integer  "photo_file_size"
    t.datetime "photo_updated_at"
  end

  create_table "types", :force => true do |t|
    t.string   "name"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
    t.string   "marker_file_name"
    t.string   "marker_content_type"
    t.integer  "marker_file_size"
    t.datetime "marker_updated_at"
    t.string   "scientific_name"
    t.string   "usda_symbol"
    t.string   "wikipedia_url"
    t.string   "edability"
    t.text     "notes"
    t.string   "synonyms"
    t.string   "scientific_synonyms"
  end

end
