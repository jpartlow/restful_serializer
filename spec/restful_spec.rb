require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Restful do

  it "should have an api_prefix accessor" do
    Restful.api_prefix.should be_nil
    Restful.api_prefix = 'foo'
    Restful.api_prefix.should == 'foo'
  end

  it "should have a model_configuration accessor" do
    Restful.model_configuration.should == {}
  end

  it "should automatically symbolize keys for model_configuration" do
    Restful.model_configuration = { 'foo' => 'bar' }
    Restful.model_configuration.should == { :foo => 'bar' }
  end

  describe "looking up model configurations" do

    class Super; end
    class SubClass < Super; end

    before(:each) do
      Restful.model_configuration = {
        :super => :super_config,
        :sub_class => :sub_class_config,
      }
    end

    it "should return an empty hash if no configuration" do
      Restful.model_configuration_for(nil).should == {}
    end

    it "should lookup entries by symbol" do
      Restful.model_configuration_for(:super).should == :super_config
    end

    it "should lookup entries from a string" do
      Restful.model_configuration_for('super').should == :super_config
    end

    it "should lookup entries by Class" do
      Restful.model_configuration_for(Super).should == :super_config
      Restful.model_configuration_for(SubClass).should == :sub_class_config
    end

    it "should lookup entries by instance class" do
      Restful.model_configuration_for(Super.new).should == :super_config
      Restful.model_configuration_for(SubClass.new).should == :sub_class_config
    end

    describe "with deep structures" do

      before(:each) do
        Restful.model_configuration = {
          :super => { :setting => {:with => :nested_hash } }
        }
      end

      it "should provide deep clones of model_configuration elements" do
        config = Restful.model_configuration_for(:super)
        config[:setting][:with] = "changed"
        Restful.model_configuration.should == {
          :super => { :setting => {:with => :nested_hash } }
        } 
      end

    end
  end
end
