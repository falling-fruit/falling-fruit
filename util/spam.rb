#!/usr/bin/env ruby

require '../config/environment'
require 'mail'

User.where("announcements_email").each{ |u|
  begin
    mail = Mail.deliver do
      from    'feedback@fallingfruit.org'
      to      u.email
      subject 'News From Falling Fruit'
      html_part do
        content_type 'text/html; charset=UTF-8'
        body    File.read('spam.txt')
      end
    end
  rescue
  end
}
