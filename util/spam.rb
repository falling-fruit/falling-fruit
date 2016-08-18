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
        body    File.read('spam.txt')
      end
    end
    puts u.email
  rescue
    puts "problem with #{u.email}"
  end
}
