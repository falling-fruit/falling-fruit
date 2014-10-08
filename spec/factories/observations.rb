include ActionDispatch::TestProcess
FactoryGirl.define do
  factory :observation do
    comment "Been there, eaten that"
    observed_on { Date.today }
    fruiting 1
    quality_rating 2
    yield_rating 3
    author "Some other dude"
    #photo { fixture_file_upload(Rails.root.join("spec","photos","loquats.jpg"), 'image/jpeg') }
    #photo_caption "Loquats for days!"
  end
end
