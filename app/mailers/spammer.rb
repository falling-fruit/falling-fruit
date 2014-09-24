class Spammer < ActionMailer::Base
  default from: "info@fallingfruit.org"

  def range_changes(user,ndays)
    @changes = Change.where("changes.created_at > NOW() - interval '? days' AND ST_INTERSECTS((SELECT range FROM users WHERE id=?),location)",ndays,user.id).joins(:location)
    return @changes.length == 0 ? nil : mail(from:"info@fallingfruit.org",to:user.email,subject:"FallingFruit.org: Weekly Updates")
  end
end
