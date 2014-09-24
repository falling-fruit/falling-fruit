require 'spec_features_helper'

describe 'api' do

  def get_auth_params(u)
    data = {email: u.email,password: u.password}
    headers = {format: :json, 'CONTENT_TYPE' => 'application/json', 'HTTPS' => 'on' }
    post '/users/sign_in.json', data.to_json, headers
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
    expect(last_request.url).to eq('https://example.org/users/sign_in.json')
  end

  it 'can issue a forgotten password request' do
    u = create(:user)
    post 'https://example.org/users/password.json', {'user' => {'email' => u.email}}.to_json,  {format: :json, 'CONTENT_TYPE' => 'application/json' }
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

    delete "/users/sign_out.json", auth_params.to_json, json_headers
    last_response.status.should eq(204)

    auth_params2 = get_auth_params(u)
    auth_params2["auth_token"].should_not be_nil
    auth_params2["auth_token"].should_not eq(auth_params["auth_token"])
  end

  subject(:driver){ create(:driver_user_with_routes) }

  it 'can fetch a list of routes' do
    auth_params = get_auth_params(driver)
    get "/routes/todo.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it 'can read route information for my routes' do
    auth_params = get_auth_params(driver)
    driver.routes.each{ |r|
      get "/routes/#{r.id}/stop_locations.json", auth_params, json_headers
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      json.should be_an(Array)
      n = json.length

      get "/routes/#{r.id}/stops.json", auth_params, json_headers
      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      json.should be_an(Array)
      json.length.should eq(n)
    }
  end

  it 'can mark a route as finalized' do
    auth_params = get_auth_params(driver)
    r = driver.routes.first
    get "/routes/#{r.id}/finalize.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Hash)
    r = Route.find(json["id"])
    r.completed_at.should_not be(nil)
  end

  it 'can mark a route as undoable' do
    auth_params = get_auth_params(driver)
    r = driver.routes.first
    get "/routes/#{r.id}/mark_undoable.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Hash)
    r = Route.find(json["id"])
    r.doers.should_not include(driver)
  end

  it 'can read donation/drop information for my routes' do
    auth_params = get_auth_params(driver)
    driver.routes.each{ |r|
      r.donations.each{ |d|
        get "/donations/#{d.id}.json", auth_params, json_headers
        json = JSON.parse(last_response.body)
        json["donation"].should_not be_nil
        json["donation"]["id"].should eq(d.id)

        d.details.each{ |dd|
          get "/donation_details/#{dd.id}.json", auth_params, json_headers
          json = JSON.parse(last_response.body)
          json["id"].should eq(dd.id)
        }
      }

      r.drops.each{ |d|
        get "/drops/#{d.id}.json", auth_params, json_headers
        json = JSON.parse(last_response.body)
        json["drop"].should_not be_nil
        json["drop"]["id"].should eq(d.id)

        d.details.each{ |dd|
          get "/drop_details/#{dd.id}.json", auth_params, json_headers
          json = JSON.parse(last_response.body)
          json["id"].should eq(dd.id)
        }
      }
    }
  end

  it 'can get a list of donors' do
    auth_params = get_auth_params(driver)
    get "/donors/list.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it 'can get a list of recipients' do
    auth_params = get_auth_params(driver)
    get "/recipients/list.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it 'can get a list of foods' do
    auth_params = get_auth_params(driver)
    get "/foods.json", auth_params, json_headers
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    json.should be_an(Array)
  end

  it 'can update a donation' do
    auth_params = get_auth_params(driver)
    donation = driver.routes.first.donations.first
    params = {rescuer_received_at:"10am",route_final_position:42,lat:100.0,lng:120.0}
    put "/donations/#{donation.id}.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    #driver = User.find(driver.id)
    donation = Donation.find(donation.id)
    #driver.position_lat.should eq(100.0)
    #driver.position_lng.should eq(120.0)
    donation.route_final_position.should eq(42)
    donation.rescuer_received_at.strftime("%H%M").should eq(DateTime.parse("10am").strftime("%H%M"))
  end

  it 'can add a donation picture' do
    auth_params = get_auth_params(driver)
    donation = driver.routes.first.donations.first
    file = File.open(Rails.root.join('spec', 'fixtures', 'test.jpg'))
    params = {photos:[{data:"FOO,"+Base64.encode64(file.read),receipt_worthy:true,name:'test.jpg',type:'image/jpg'}]}
    file.close
    post "/donations/#{donation.id}/add_photos.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)
    donation.photos.length.should eq(1)
  end

  it 'can add a donation detail picture' do
    auth_params = get_auth_params(driver)
    donation = driver.routes.first.donations.first.details.first
    file = File.open(Rails.root.join('spec', 'fixtures', 'test.jpg'))
    params = {photos:[{data:"FOO,"+Base64.encode64(file.read),receipt_worthy:true,name:'test.jpg',type:'image/jpg'}]}
    file.close
    post "/donation_details/#{donation.id}/add_photos.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)
    donation.photos.length.should eq(1)
  end

  it 'can add a drop detail picture' do
    auth_params = get_auth_params(driver)
    drop = driver.routes.first.drops.first.details.first
    file = File.open(Rails.root.join('spec', 'fixtures', 'test.jpg'))
    params = {photos:[{data:"FOO,"+Base64.encode64(file.read),receipt_worthy:true,name:'test.jpg',type:'image/jpg'}]}
    file.close
    post "/drop_details/#{drop.id}/add_photos.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)
    drop.photos.length.should eq(1)
  end

  it 'can add a drop picture' do
    auth_params = get_auth_params(driver)
    drop = driver.routes.first.drops.first
    file = File.open(Rails.root.join('spec', 'fixtures', 'test.jpg'))
    params = {photos:[{data:"FOO,"+Base64.encode64(file.read),receipt_worthy:true,name:'test.jpg',type:'image/jpg'}]}
    file.close
    post "/drops/#{drop.id}/add_photos.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)
    drop.photos.length.should eq(1)
  end

  it 'can update a drop' do
    auth_params = get_auth_params(driver)
    drop = driver.routes.first.drops.first
    params = {rescuer_released_at:"10am",route_final_position:42,lat:100.0,lng:120.0}
    put "/drops/#{drop.id}.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    drop = Drop.find(drop.id)
    drop.route_final_position.should eq(42)
    drop.rescuer_released_at.strftime("%H%M").should eq(DateTime.parse("10am").strftime("%H%M"))
  end

  it 'can update a drop detail' do
    food = create(:food)
    auth_params = get_auth_params(driver)
    detail = driver.routes.first.drops.first.details.first
    donation = detail.drop.route.donations.sample
    params = {food_id:food.id,quantity:42,quantity_unit:0,weight:24,weight_unit:0,rescuer_comment:"FooBar",temperature:200,temp_unit:0,donation_number:donation.donation_number}
    put "/drop_details/#{detail.id}.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    detail = DropDetail.find(detail.id)
    detail.quantity.should eq(42)
    detail.food_id.should eq(food.id)
    detail.quantity_unit.should eq(0)
    detail.weight.should eq(24)
    detail.weight_unit.should eq(0)
    detail.rescuer_comment.should eq("FooBar")
    detail.temperature.should eq(200)
    detail.donation.should eq(donation)
  end

  it 'can update a donation detail' do
    food = create(:food)
    auth_params = get_auth_params(driver)
    detail = driver.routes.first.donations.first.details.first
    params = {food_id:food.id,quantity:42,quantity_unit:0,weight:24,weight_unit:0,rescuer_comment:"FooBar",temperature:200,temp_unit:0}
    put "/donation_details/#{detail.id}.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    detail = DonationDetail.find(detail.id)
    detail.quantity.should eq(42)
    detail.food_id.should eq(food.id)
    detail.quantity_unit.should eq(0)
    detail.weight.should eq(24)
    detail.weight_unit.should eq(0)
    detail.rescuer_comment.should eq("FooBar")
    detail.temperature.should eq(200)
  end

  it 'can create a donation detail' do
    food = create(:food)
    auth_params = get_auth_params(driver)
    donation = driver.routes.first.donations.first
    params = {donation_id:donation.id,food_id:food.id,quantity:42,quantity_unit:0,weight:24,
              weight_unit:0,rescuer_comment:"FooBar",temperature:200,temp_unit:0}
    post "/donation_details.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    detail = DonationDetail.find(json["id"])
    detail.quantity.should eq(42)
    detail.food_id.should eq(food.id)
    detail.quantity_unit.should eq(0)
    detail.weight.should eq(24)
    detail.weight_unit.should eq(0)
    detail.rescuer_comment.should eq("FooBar")
    detail.temperature.should eq(200)
  end

  it 'can create a drop detail' do
    food = create(:food)
    auth_params = get_auth_params(driver)
    drop = driver.routes.first.drops.first
    donation = drop.route.donations.sample
    params = {drop_id:drop.id,food_id:food.id,quantity:42,quantity_unit:0,weight:24,
              weight_unit:0,rescuer_comment:"FooBar",temperature:200,temp_unit:0,
              donation_number:donation.donation_number}
    post "/drop_details.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    detail = DropDetail.find(json["id"])
    detail.quantity.should eq(42)
    detail.food_id.should eq(food.id)
    detail.quantity_unit.should eq(0)
    detail.weight.should eq(24)
    detail.weight_unit.should eq(0)
    detail.rescuer_comment.should eq("FooBar")
    detail.temperature.should eq(200)
    detail.donation.should eq(donation)
  end

  it 'can create a drop' do
    auth_params = get_auth_params(driver)
    recipient = create(:recipient)
    route = driver.routes.first
    params = {route_id:route.id,route_position:32,route_final_position:23,rescuer_comment:"FooBar",recipient_id:recipient.id,
              dropped_on:Time.zone.today,rescuer_released_at:"4am"}
    post "/drops.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    drop = Drop.find(json["id"])
    drop.route_final_position.should eq(23)
    drop.route_position.should eq(32)
    drop.rescuer_released_at.strftime("%H%M").should eq(DateTime.parse("4am").strftime("%H%M"))
    drop.rescuer_comment.should eq("FooBar")
    drop.recipient_id.should eq(recipient.id)
    drop.route_id.should eq(route.id)
    drop.dropped_on.should eq(Time.zone.today)
  end

  it 'can create a donation' do
    auth_params = get_auth_params(driver)
    donor = create(:donor)
    route = driver.routes.first
    params = {route_id:route.id,route_position:32,route_final_position:23,rescuer_comment:"FooBar",donor_id:donor.id,
              available_on:Time.zone.today,rescuer_received_at:"4am"}
    post "/donations.json", params.merge(auth_params).to_json, json_headers
    last_response.should be_ok
    json = JSON.parse(last_response.body)
    json["status"].should eq(0)

    drop = Donation.find(json["id"])
    drop.route_final_position.should eq(23)
    drop.route_position.should eq(32)
    drop.rescuer_received_at.strftime("%H%M").should eq(DateTime.parse("4am").strftime("%H%M"))
    drop.rescuer_comment.should eq("FooBar")
    drop.donor_id.should eq(donor.id)
    drop.route_id.should eq(route.id)
    drop.available_on.should eq(Time.zone.today)
  end

  it 'can delete a donation detail' do
    auth_params = get_auth_params(driver)
    detail = driver.routes.first.donations.first.details.first
    delete "/donation_details/#{detail.id}.json", auth_params.to_json, json_headers
    last_response.should be_ok
    DonationDetail.where("id = #{detail.id}").count.should eq(0)
  end

  it 'can delete a drop detail' do
    auth_params = get_auth_params(driver)
    detail = driver.routes.first.drops.first.details.first
    delete "/drop_details/#{detail.id}.json", auth_params.to_json, json_headers
    last_response.should be_ok
    DropDetail.where("id = #{detail.id}").count.should eq(0)
  end

  it 'can delete a drop' do
    auth_params = get_auth_params(driver)
    drop = driver.routes.first.drops.first
    delete "/drops/#{drop.id}.json", auth_params.to_json, json_headers
    last_response.should be_ok
    Drop.where("id = #{drop.id}").count.should eq(0)
  end

  it 'can delete a donation' do
    auth_params = get_auth_params(driver)
    donation = driver.routes.first.donations.first
    delete "/donations/#{donation.id}.json", auth_params.to_json, json_headers
    last_response.should be_ok
    Donation.where("id = #{donation.id}").count.should eq(0)
  end

end