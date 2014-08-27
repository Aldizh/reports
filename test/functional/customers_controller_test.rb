require 'test_helper'

class CustomersControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get getInfo" do
    get :getInfo
    assert_response :success
  end

end
