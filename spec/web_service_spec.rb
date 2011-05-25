require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Restful::Configuration::WebService do

  after(:each) do
    Restful.clear
  end

  describe "looking up resource configurations" do

    class Super; end
    class SubClass < Super; end

    before(:each) do
      @ws = Restful::Configuration::WebService.register('service') do |ws|
        @super_config = ws.register_resource(:super)
        @sub_class_config = ws.register_resource(:sub_class)
      end 
    end

    it "should return nil if no configuration" do
      @ws.resource_configuration_for(nil).should be_nil
    end

    it "should lookup entries by symbol" do
      @ws.resource_configuration_for(:super).should == @super_config
    end

    it "should lookup entries from a string" do
      @ws.resource_configuration_for('super').should == @super_config
    end

    it "should lookup entries by Class" do
      @ws.resource_configuration_for(Super).should == @super_config
      @ws.resource_configuration_for(SubClass).should == @sub_class_config
    end

    it "should lookup entries by instance class" do
      @ws.resource_configuration_for(Super.new).should == @super_config
      @ws.resource_configuration_for(SubClass.new).should == @sub_class_config
    end

  end

  describe "provided resource configurations" do

    before(:each) do
      @ws = Restful::Configuration::WebService.register('service') do |ws|
        @gold_config = ws.register_resource(:super, 
          :serialization => { :only => :foo }
        )
      end
      @config = @ws.resource_configuration_for(:super)
    end

    it "should produce a clone" do
      @config.should == @gold_config
      @config.should_not equal(@gold_config)
    end

    it "should produce a deep clone" do
      @config.serialization.should == @gold_config.serialization
      @config.serialization.should_not equal(@gold_config.serialization)
    end
  end
end
