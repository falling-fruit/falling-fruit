require 'spec_features_helper'

describe 'api' do

  ### AUTHENTICATION STUFF

  def get_auth_params(u)
    data = {email: u.email,password: u.password}
    headers = {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
    post '/api/users/sign_in.json', data.to_json, headers
    expect(last_response.status).to eq(201)
    json = JSON.parse(last_response.body)
    return {"auth_token" => json["auth_token"], "auth_id" => u.email }
  end

  def json_headers
    {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
  end

  it 'forces https' do
    u = create(:user)
    data = {email: u.email,password: u.password}.to_json
    post 'http://example.org/users/sign_in.json', data, {format: :json, 'CONTENT_TYPE' => 'application/json' }
    last_response.should be_redirect   # This works, but I want it to be more specific
    follow_redirect!
    expect(last_response.status).to eq(200)
    expect(last_request.url).to eq('https://example.org/api/users/sign_in.json')
  end

  it 'can issue a forgotten password request' do
    u = create(:user)
    post 'https://example.org/api/users/password.json', {'user' => {'email' => u.email}}.to_json,  {format: :json, 'CONTENT_TYPE' => 'application/json' }
    expect(last_response.status).to eq(201)
    json = JSON.parse(last_response.body)
    json.should be_empty
    ActionMailer::Base.deliveries.last.to.should include u.email
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

    delete "/api/users/sign_out.json", auth_params.to_json, json_headers
    last_response.status.should eq(204)

    auth_params2 = get_auth_params(u)
    auth_params2["auth_token"].should_not be_nil
    auth_params2["auth_token"].should_not eq(auth_params["auth_token"])
  end

  ### THESE METHODS CAN WORK WITHOUT AUTHENITCATION

  it "can get type cluster data" do
    bounds = 'nelat=70.95969447189823&nelng=128.67188250000004&swlat=-23.241353692881138&swlng=132.18750749999998'
    get "/api/locations/cluster_types.json?grid=4&#{bounds}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get data for one location" do
    get "/api/locations/1023.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
  end

  it "can get cluster data" do
    bounds = 'nelat=70.95969447189823&nelng=128.67188250000004&swlat=-23.241353692881138&swlng=132.18750749999998'
    get "/api/locations/cluster.json?method=grid&grid=2&#{bounds}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get marker data" do
    bounds = 'nelat=39.995268865220254&nelng=-105.2207126204712&swlat=39.98579953528965&swlng=-105.26422877952882'
    get "/api/locations/markers.json?muni=1&#{bounds}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get review info for a location" do
    get "/api/locations/1023/reviews.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get info for nearby locations" do
    loc = 'lat=39.991106&lng=-105.247455'
    get "/api/locations/nearby.json?#{loc}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it "can get subsequent pages of nearby locations" do
    loc = 'lat=39.991106&lng=-105.247455'
    get "/api/locations/nearby.json?#{loc}", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
    # check that pagination does something
    get "/api/locations/nearby.json?#{loc}&offset=100", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json2 = JSON.parse(last_response.body)
    json2.should be_an(Array)
    json[0][:id].should not_eq(json2[0][:id])
  end

  ### THESE METHODS NEED AN AUTHENTICATED USER

  it "can create a location"
  it "can edit a location"

  it "can get info for a users' locations" do
    u = create(:user)
    auth_params = get_auth_params(u)
  end

  it "can get info for a users' favorite locations" do
    u = create(:user)
    auth_params = get_auth_params(u)
  end

  # ex.:

  #it 'can add a picture' do
  #  auth_params = get_auth_params(driver)
  #  donation = driver.routes.first.donations.first
  #  file = File.open(Rails.root.join('spec', 'fixtures', 'test.jpg'))
  #  params = {photos:[{data:"FOO,"+Base64.encode64(file.read),receipt_worthy:true,name:'test.jpg',type:'image/jpg'}]}
  #  file.close
  #  post "/donations/#{donation.id}/add_photos.json", params.merge(auth_params).to_json, json_headers
  #  last_response.should be_ok
  #  json = JSON.parse(last_response.body)
  #  json["status"].should eq(0)
  #  donation.photos.length.should eq(1)
  #end

  #it 'can update a drop' do
  #  auth_params = get_auth_params(driver)
  #  drop = driver.routes.first.drops.first
  #  params = {rescuer_released_at:"10am",route_final_position:42,lat:100.0,lng:120.0}
  #  put "/drops/#{drop.id}.json", params.merge(auth_params).to_json, json_headers
  #  last_response.should be_ok
  #  json = JSON.parse(last_response.body)
  #  json["status"].should eq(0)
  #
  #  drop = Drop.find(drop.id)
  #  drop.route_final_position.should eq(42)
  #  drop.rescuer_released_at.strftime("%H%M").should eq(DateTime.parse("10am").strftime("%H%M"))
  #end

end