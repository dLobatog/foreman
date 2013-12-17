require 'test_helper'

class Api::V2::SubnetsControllerTest < ActionController::TestCase

  valid_attrs = { :name => 'QA2', :network => '10.35.2.27', :mask => '255.255.255.0' }

  test "index content is a JSON array" do
    get :index
    subnets = ActiveSupport::JSON.decode(@response.body)
    assert subnets['results'].is_a?(Array)
    assert_response :success
    assert !subnets.empty?
  end

  test "should show individual record" do
    get :show, { :id => subnets(:one).to_param }
    assert_response :success
    show_response = ActiveSupport::JSON.decode(@response.body)
    assert !show_response.empty?
  end

  test "should create subnet" do
    assert_difference('Subnet.count') do
      post :create, { :subnet => valid_attrs }
    end
    assert_response :success
  end

  test "does not create subnet with non-existent domain" do
    post :create, { :subnet => valid_attrs.merge( :domain_ids => [1, 2] ) }
    assert_response :not_found
  end

  test "should update subnet" do
    put :update, { :id => subnets(:one).to_param, :subnet => { } }
    assert_response :success
  end

  test "should destroy subnets" do
    assert_difference('Subnet.count', -1) do
      delete :destroy, { :id => subnets(:three).to_param }
    end
    assert_response :success
  end

  test "should NOT destroy subnet that is in use" do
    assert_difference('Subnet.count', 0) do
      delete :destroy, { :id => subnets(:one).to_param }
    end
    assert_response :unprocessable_entity
  end

  test "delete destroys subnet not in use" do
    subnet = Subnet.first
    subnet.hosts.clear
    subnet.interfaces.clear
    as_admin { delete :destroy, {:id => subnet.id} }
    ActiveSupport::JSON.decode(@response.body)
    assert_response :ok
    assert !Subnet.exists?(:id => subnet.id)
  end
end
