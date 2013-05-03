module ApplicationHelper

  def faster_time_ago_in_words(t)
    days = (Time.now-t)/(60*60*24)
    if days < 1
      "less than 24 hours"
    elsif days < 31
      "#{days.ceil} days"
    elsif days < 365
      months = days/31
      if months == 1
        "last month"
      else
        "#{months.floor} months ago"
      end
    elsif
      years = days/365
      if years == 1
        "last year"
      else
        "#{years.floor} years ago"
      end
    end
  end

end
