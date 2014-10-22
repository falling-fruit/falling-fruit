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

  it "can get type cluster data" do
    api_key = ApiKey.find_by_name('MobileApp')
    bounds = 'nelat=70.95969447189823&nelng=128.67188250000004&swlat=-23.241353692881138&swlng=132.18750749999998&'
    get "/api/locations/cluster_types.json?grid=4&#{bounds}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get data for one location" do
    api_key = ApiKey.find_by_name('MobileApp')
    get "/api/locations/#{a_location.id}.json&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
  end

  it "can get cluster data" do
    api_key = ApiKey.find_by_name('MobileApp')
    bounds = 'nelat=70.95969447189823&nelng=128.67188250000004&swlat=-23.241353692881138&swlng=132.18750749999998'
    get "/api/locations/cluster.json?method=grid&grid=2&#{bounds}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get marker data" do
    api_key = ApiKey.find_by_name('MobileApp')
    bounds = 'nelat=39.995268865220254&nelng=-105.2207126204712&swlat=39.98579953528965&swlng=-105.26422877952882'
    get "/api/locations/markers.json?muni=1&#{bounds}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get review info for a location" do
    api_key = ApiKey.find_by_name('MobileApp')
    get "/api/locations/#{a_location.id}/reviews.json?api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get info for nearby locations" do
    api_key = ApiKey.find_by_name('MobileApp')
    loc = 'lat=39.991106&lng=-105.247455'
    get "/api/locations/nearby.json?#{loc}&api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get subsequent pages of nearby locations" do
    api_key = ApiKey.find_by_name('MobileApp')
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
    api_key = ApiKey.find_by_name('MobileApp')
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

  it "prevents editing when not authenticated" do
    api_key = ApiKey.find_by_name('MobileApp')
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    put "/api/locations/#{a_location.id}.json?api_key=#{api_key.api_key}", params.to_json, json_headers
    expect(last_response.status).to_not eq(200)
  end

  it "can create a location" do
    api_key = ApiKey.find_by_name('MobileApp')
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

  it "prevents creation when not authenticated" do
    api_key = ApiKey.find_by_name('MobileApp')
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    post "/api/locations.json?api_key=#{api_key.api_key}", params.to_json, json_headers
    expect(last_response.status).to_not eq(200)
  end

  it "can get info for a users' locations" do
    api_key = ApiKey.find_by_name('MobileApp')
    u = create(:user)
    a_location.observations.each{ |o| o.user = u }
    a_location.user = u
    a_location.save
    auth_params = get_auth_params(u)
    get "/api/locations/mine.json?api_key=#{api_key.api_key}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
    json.length.should eq(1)
  end

  it "can get info for a users' favorite locations"

end