FactoryGirl.define do
  factory :location do
    lat 39.986606
    lng -105.242404
    author "Some Dood"
    description "Hella sweet apple trees"
    address "440 S 45th St., Boulder, CO, 80305" #  fixme: randomize location
  end

  factory :location_with_observation do
    after(:create) do |location|
      location.observations << create(:observation,location:location)
    end
  end
end
