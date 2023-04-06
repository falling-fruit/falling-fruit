require 'spec_helper'

describe 'mobile_api' do

  ### AUTHENTICATION STUFF

  def get_auth_params(u)
    data = {user: {email: u.email,password: u.password} }
    headers = {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
    post '/users/sign_in.json', data.to_json, headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    return {"auth_token" => json["auth_token"]}
  end

  def json_headers
    {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
  end

  it 'can sign in' do
    u = create(:user)
    auth_params = get_auth_params(u)
    auth_params["auth_token"].should_not be_nil
  end

  it 'can sign up' do
    data = {:user => {:email => 'foo@bar.com', :password => 'FooBar',
            :name => 'Foo Bar', :add_anonymously => false,
            :announcements_email => false, :bio => 'Testing123', :roles_mask => 42}}
    headers = {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
    post '/users.json', data.to_json, headers
    expect(last_response.status).to eq(201)
    u = User.find_by_email('foo@bar.com')
    u.should_not be_nil
    # user shouldn't be able to set thier own role
    u.roles_mask.should_not eq(42)
  end

  it 'can sign out' do
    u = create(:user)
    auth_params = get_auth_params(u)
    auth_params["auth_token"].should_not be_nil

    delete "/users/sign_out.json", auth_params.to_json, json_headers
    last_response.status.should eq(204)

    auth_params2 = get_auth_params(u)
    auth_params2["auth_token"].should_not be_nil
    auth_params2["auth_token"].should_not eq(auth_params["auth_token"])
  end

  ### THESE METHODS CAN WORK WITHOUT AUTHENTICATION

  subject(:a_location) { create(:location_with_observation) }
  subject(:api_key) { create(:api_key) }

  it "can get data for one location" do
    l = create(:location_with_observation)
    get "/api/locations/#{l.id}.json?api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
  end

  it "can get marker data" do
    bounds = 'nelat=39.995268865220254&nelng=-105.2207126204712&swlat=39.98579953528965&swlng=-105.26422877952882'
    get "/api/locations/markers.json?muni=1&#{bounds}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get review info for a location" do
    get "/api/locations/#{a_location.id}/reviews.json?api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get info for nearby locations" do
    loc = 'lat=39.991106&lng=-105.247455'
    get "/api/locations/nearby.json?#{loc}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get subsequent pages of nearby locations" do
    loc = 'lat=39.991106&lng=-105.247455'
    get "/api/locations/nearby.json?#{loc}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
    # check that pagination does something
    get "/api/locations/nearby.json?#{loc}&offset=100&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json2 = JSON.parse(last_response.body)
    json2.should be_an(Array)
    #json[0][:id].should not_eq(json2[0][:id])
  end

  ### THESE METHODS NEED AN AUTHENTICATED USER

  it "can edit a location" do
    u = create(:user)
    auth_params = get_auth_params(u)
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    put "/api/locations/#{a_location.id}.json?api_key=#{api_key.api_key}", params.merge(auth_params).to_json, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    json["status"].should eq(0)
    a_location.reload
    a_location.description.should eq(params[:location][:description])
    a_location.types.length.should eq(3)
  end

  it "can edit a location with an added review and photo" do
    u = create(:user)
    auth_params = get_auth_params(u)
    file = File.open(Rails.root.join('spec', 'photos', 'loquats.jpg'))
    params = {
      :location => {
        :description => "this is a test update",
        :observation => {:comment => "testing 123",
                         :photo_data => {data:Base64.encode64(file.read),name:"test.jpg",type:'image/jpg'}
                        }
      },:types => "Apple,Potato,Grapefruit"
    }
    file.close
    put "/api/locations/#{a_location.id}.json?api_key=#{api_key.api_key}", params.merge(auth_params).to_json, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    json["status"].should eq(0)
    a_location.reload
    a_location.description.should eq(params[:location][:description])
    a_location.observations.last.comment.should eq("testing 123")
    a_location.observations.last.photo_file_name.should_not be_nil
    a_location.types.length.should eq(3)
  end

  it "prevents editing when not authenticated" do
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    put "/api/locations/#{a_location.id}.json?api_key=#{api_key.api_key}", params.to_json, json_headers
    expect(last_response.status).to_not eq(200)
  end

  it "can create a location" do
    u = create(:user)
    auth_params = get_auth_params(u)
    params = {:location => {:description => "this is a test create",:lat => 41.133745, :lng => -71.524588},
              :types => "Apple,Potato,Grapefruit"}
    post "/locations.json?api_key=#{api_key.api_key}", params.merge(auth_params).to_json, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    puts json
    json["status"].should eq(0)
    id = json["id"].to_i
    loc = Location.find(id)
    loc.description.should eq(params[:location][:description])
    loc.types.length.should eq(3)
  end

  it "can create a location with a photo and review" do
    u = create(:user)
    auth_params = get_auth_params(u)
    file = File.open(Rails.root.join('spec', 'photos', 'loquats.jpg'))
    params = {
      :location => {
                :description => "this is a test create",:lat => 41.133745, :lng => -71.524588,
                :observation => {:quality_rating => 4, :yield_rating => 1, :comment => "test",
                  :photo_data => {data:Base64.encode64(file.read),name:"test.jpg",type:'image/jpg'},
                  :observed_on => '12/12/2014'
                },
      },
      :types => "Apple,Potato,Grapefruit"
    }
    file.close
    post "/locations.json?api_key=#{api_key.api_key}", params.merge(auth_params).to_json, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    puts json
    json["status"].should eq(0)
    id = json["id"].to_i
    loc = Location.find(id)
    loc.description.should eq(params[:location][:description])
    loc.observations.first.comment.should eq(params[:location][:observation][:comment])
    loc.observations.first.photo_file_name.should_not be_nil
    loc.types.length.should eq(3)
  end


  it "prevents creation when not authenticated" do
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    post "/api/locations.json?api_key=#{api_key.api_key}", params.to_json, json_headers
    expect(last_response.status).to_not eq(200)
  end

  it "can get info for a users' locations" do
    u = create(:user)
    l = create(:location_with_observation)
    l.observations.each{ |o| o.user = u; o.save }
    l.user = u
    l.save
    auth_params = get_auth_params(u)
    get "/api/locations/mine.json?api_key=#{api_key.api_key}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
    json.length.should eq(1)
  end

end
