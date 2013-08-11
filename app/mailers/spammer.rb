class Spammer < ActionMailer::Base
  default from: "info@fallingfruit.org"

  def range_changes(user,ndays)
    @user = user
    #r = ActiveRecord::Base.connection.execute("SELECT string_agg(coalesce(t.name,lt.type_other),',') as type_title,
    #  extract(days from (NOW()-c.created_at)) as days_ago, c.location_id, c.user_id, c.description, c.remote_ip, l.city, l.state, l.country
    #  FROM changes c, users u, locations l, locations_types lt left outer join types t on lt.type_id=t.id
    #  WHERE lt.location_id=l.id AND l.id=c.location_id AND u.id=#{user.id} AND 
    #        ST_INTERSECTS(u.range,l.location) AND c.created_at > NOW() - interval '#{ndays} days'
    #  GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at ORDER BY c.created_at DESC LIMIT 100");
    #@changes = r.collect{ |row| row }
    @changes = Change.where("changes.created_at > NOW() - interval '? days' AND ST_INTERSECTS((SELECT range FROM users WHERE id=?),location)",ndays,user.id).joins(:location)
    return @changes.length == 0 ? nil : mail(to:user.email,subject:"FallingFruit.org: Weekly Updates")
  end
end
