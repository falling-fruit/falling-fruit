class Spammer < ActionMailer::Base
  default from: "info@fallingfruit.org"

  def range_changes(user,ndays)
    @changes = Change.where("changes.created_at > NOW() - interval '? days' AND ST_INTERSECTS((SELECT range FROM users WHERE id=?),location)",ndays,user.id).joins(:location)
    return @changes.length == 0 ? nil : mail(from:"info@fallingfruit.org",to:user.email,subject:"FallingFruit.org: Weekly Updates")
  end
  
  def respond_to_problem(problem)
    unless problem.reporter.nil? 
      name = problem.reporter.name.nil? ? '' : ' ' + problem.reporter.name
      email = problem.reporter.email
    else
      name = problem.name.nil? ? '' : ' ' + problem.name
      email = problem.email
    end
    action = problem.resolution_code.nil? ? 'made no changes' : Problem::Resolutions[problem.resolution_code].downcase
    location_url = problem.location.nil? ? '#' + problem.location_id.to_s : '<a href="http://fallingfruit.org/locations/' + problem.location_id.to_s + '">#' + problem.location_id.to_s + '</a>'
    problem_comment = '"' + Problem::Codes[problem.problem_code] + ' - <i>' + problem.comment + '</i>"'
    signature = problem.responder.nil? ? (problem.responder.name.nil? ? 'An anonymous admin' : problem.responder.name) + "<br/>fallingfruit.org" : "fallingfruit.org"
    mail(
      from: "info@fallingfruit.org",
      to: email,
      subject: "Falling Fruit Location #" + problem.location_id.to_s,
      body: "Hi" + name + "," + 
        "<p>Thank you for reporting a problem for location" + location_url + ":</p>" + 
        "<p>" + problem_comment + "<p>" +
        "<p>We have " + action + ". " + problem.response.to_s + "</p>" + 
        "Let ue know if you have any additional questions or concerns.<br/>thank you,<br/>" +
         signature
      )
  end
  
end