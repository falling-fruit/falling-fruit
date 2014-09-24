FactoryGirl.define do
  factory :user do
    sequence(:name) { |n| "John Doe the #{n.ordinalize}" }
    sequence(:email) { |n| "user#{n}@gmail.com" }
    bio "OMG I like fruit"
    address "440 S 45th St., Boulder, CO, 80305"
    range_radius 50.0
    lat 39.986606
    lng -105.242404
    password "SomePassword"
    confirmed_at Time.zone.now
  end
end
