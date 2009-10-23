require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Stream do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :user_id => 1,
      :categories_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    Stream.create!(@valid_attributes)
  end
end
