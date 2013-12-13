class ImportExistingPhotosFromUrLs < ActiveRecord::Migration
  def change
    Location.where("photo_url IS NOT NULL and photo_url != ''").each{ |l|
      begin
        o = Observation.new
        o.photo = open(l.photo_url) # will throw an exception if url is no good
        o.location = l
        o.save
        puts "+ #{l.photo_url}"
      rescue
        puts "- #{l.photo_url}"
      end     
    }
    remove_column :locations, :photo_url
  end
end
