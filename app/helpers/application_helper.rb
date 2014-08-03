module ApplicationHelper

  def faster_time_ago_in_words(t)
    days = (Time.now-t)/(60*60*24)
    if days < 1
      I18n.t("helpers.faster_time_ago_in_words.less_than_24_hours", :default => "less than 24 hours")
    elsif days < 31
      "#{days.ceil} " + I18n.t("helpers.faster_time_ago_in_words.days", :default => "days")
    elsif days < 365
      months = days/31
      if months == 1
        I18n.t("helpers.faster_time_ago_in_words.last_month", :default => "last month")
      else
        "#{months.floor} " + I18n.t("helpers.faster_time_ago_in_words.months_ago",:default => "months ago")
      end
    elsif
      years = days/365
      if years == 1
        I18n.t("helpers.faster_time_ago_in_words.last_year",:default => "last year")
      else
        "#{years.floor} " + I18n.t("helpers.faster_time_ago_in_words.years_ago", :default => "years ago")
      end
    end
  end

end
