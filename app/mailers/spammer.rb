class Spammer < ActionMailer::Base
  default :from => "info@fallingfruit.org"

  def range_changes(user,ndays)
    return nil if user.nil?
    headers['X-SMTPAPI'] = '{"category": "FF-Rails-RangeUpdate"}'
    @changes = Change.where("changes.created_at > NOW() - interval '? days' AND ST_INTERSECTS((SELECT range FROM users WHERE id=?),location)",ndays,user.id).joins(:location)
    return @changes.length == 0 ? nil : mail(:to => "cphillips@smallwhitecube.com", :subject => "FallingFruit.org: Weekly Updates")
  end
  
  def respond_to_problem(problem)
    headers['X-SMTPAPI'] = '{"category": "FF-Rails-ProblemResponse"}'
    unless problem.resolution_code.nil?
      @problem = problem
      unless problem.reporter.nil? 
        email = problem.reporter.email
      else
        email = problem.email
      end
      unless email.nil?
        subject = "Falling Fruit Location #" + problem.location_id.to_s
        mail(
          :to => email,
          :subject => subject
        )
      else
        return nil
      end
    else
      return nil
    end
  end
  
end
