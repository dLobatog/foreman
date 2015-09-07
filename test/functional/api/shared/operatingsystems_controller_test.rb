module OperatingsystemsControllerTest
  extend ActiveSupport::Concern
  included do
    os = {
      :name  => "awsome_os",
      :major => "1",
      :minor => "2"
    }

    test "should get index" do
      get :index, { }
      assert_response :success
      assert_not_nil assigns(:operatingsystems)
    end

    test "should show os" do
      get :show, { :id => operatingsystems(:redhat).to_param }
      assert_response :success
      assert_not_nil assigns(:operatingsystem)
      show_response = ActiveSupport::JSON.decode(@response.body)
      assert !show_response.empty?
    end

    test "should create os" do
      assert_difference('Operatingsystem.count') do
        post :create, { :operatingsystem => os }
      end
      assert_response :created
      assert_not_nil assigns(:operatingsystem)
    end

    test "should not create os without version" do
      assert_difference('Operatingsystem.count', 0) do
        post :create, { :operatingsystem => os.except(:major) }
      end
      assert_response :unprocessable_entity
    end

    test "should update os" do
      put :update, { :id => operatingsystems(:redhat).to_param, :operatingsystem => { :name => "new_name" } }
      assert_response :success
    end

    test "should destroy os" do
      assert_difference('Operatingsystem.count', -1) do
        delete :destroy, { :id => operatingsystems(:no_hosts_os).to_param }
      end
      assert_response :success
    end

    test "should show os if id is fullname" do
      get :show, { :id => operatingsystems(:centos5_3).fullname }
      assert_response :success
      assert_equal operatingsystems(:centos5_3), assigns(:operatingsystem)
    end

    test "should show os if id is description" do
      get :show, { :id => operatingsystems(:redhat).description }
      assert_response :success
      assert_equal operatingsystems(:redhat), assigns(:operatingsystem)
    end
  end
end
