class Spammer < ActionMailer::Base
  default :from => "info@fallingfruit.org"

  def range_changes(user,ndays)
    @changes = Change.where("changes.created_at > NOW() - interval '? days' AND ST_INTERSECTS((SELECT range FROM users WHERE id=?),location)",ndays,user.id).joins(:location)
    return @changes.length == 0 ? nil : mail(:to => user.email, :subject => "FallingFruit.org: Weekly Updates")
  end
  
  def respond_to_problem(problem)
    unless problem.resolution_code.nil?
      @problem = problem
      unless problem.reporter.nil? 
        email = problem.reporter.email
      else
        email = problem.email
      end
      subject = "Falling Fruit Location #" + problem.location_id.to_s
      mail(
        :to => email,
        :subject => subject
        )
    else
      return nil
    end
  end
  
end