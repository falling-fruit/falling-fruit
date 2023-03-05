require 'spec_helper'

describe 'muni_api' do

  ### AUTHENTICATION STUFF

  def json_headers
    {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
  end

  subject(:a_location) { create(:location_with_observation) }
  subject(:api_key) { create(:api_key) }

  it "can get data for one location" do
    get "/api/locations/#{a_location.id}.json&api_key=#{api_key.api_key}", {}, json_headers
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
    #json[0][:id].should_not eq(json2[0][:id])
  end

  # NEGATIVE TESTS

  it "cannot get review info for a location" do
    get "/api/locations/#{a_location.id}/reviews.json?api_key=#{api_key.api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    json["error"].should_not be_nil
  end

  it "cannot get marker data with a bad key" do
    api_key = "FOOBAR"
    bounds = 'nelat=39.995268865220254&nelng=-105.2207126204712&swlat=39.98579953528965&swlng=-105.26422877952882'
    get "/api/locations/markers.json?muni=1&#{bounds}&api_key=#{api_key}", {}, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_a(Hash)
    json["error"].should_not be_nil
  end

  it "prevents creation when not authenticated" do
    params = {:location => {:description => "this is a test update"},:types => "Apple,Potato,Grapefruit"}
    post "/api/locations.json?api_key=#{api_key.api_key}", params.to_json, json_headers
    expect(last_response.status).to_not eq(200)
  end

end
