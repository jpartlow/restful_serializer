require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

ActionController::Routing::Routes.draw do |map|
  map.resources :foos
  map.prefix_foo 'prefix/foos/:id', :controller => 'foos', :action => 'show'
  map.custom_foo 'custom_foo/:id', :controller => 'foos', :action => 'show'
  map.resources :bars do |bars|
    bars.resources :dingos
  end 
  map.resources :things
end

describe Restful::Serializer do

  class Foo < ActiveRecord::Base
    has_many :bars
    def fancy_name
      "fancy: #{name}"
    end

    def a_method
      "calculated value"
    end
  end

  class Bar < ActiveRecord::Base
    belongs_to :foo
    has_one :one
    has_many :dingos
  end

  class Dingo < ActiveRecord::Base
    belongs_to :bar
  end

  class Thing < ActiveRecord::Base; end
  class Sub < Thing; end

  def generate_instances
    @foo = Foo.create!(:name => 'A foo')
    @bar1 = Bar.create!(:name => 'The bar1', :foo => @foo)
    @bar2 = Bar.create!(:name => 'The bar2', :foo => @foo)
    @dingo1 = Dingo.create!(:name => 'The dingo1', :bar => @bar1)
    @dingo2 = Dingo.create!(:name => 'The dingo2', :bar => @bar1)
    @dingo3 = Dingo.create!(:name => 'The dingo3', :bar => @bar2)
    @dingo4 = Dingo.create!(:name => 'The dingo4', :bar => @bar2)
  end

  before(:all) do
    create_schema do |conn|
      conn.create_table(:foos, :force => true) do |t|
        t.string :name
      end
      conn.create_table(:bars, :force => true) do |t|
        t.string :name
        t.references :foo
      end
      conn.create_table(:dingos, :force => true) do |t|
        t.string :name
        t.references :bar
      end
      conn.create_table(:things, :force => true) do |t|
        t.string :name
        t.string :type 
        t.string :secret
      end
    end 
  end

  before(:each) do
    @foo = Foo.new(:name => 'A foo')
    Restful::Serializer.default_url_options = { :host => 'test.org' }
  end

  after(:each) do
    Restful.api_prefix = nil
    Restful.model_configuration = {}
  end

  it "should require a subject" do
    lambda { Restful::Serializer.new }.should raise_error(ArgumentError)
    Restful::Serializer.new('foo').should be_kind_of(Restful::Serializer)
  end

  it "should set klass" do
    rs = Restful::Serializer.new(@foo)
    rs.klass.should == 'foo'
  end

  it "should serialize" do
    @foo.save!
    rs = Restful::Serializer.new(@foo)
    rs.serialize.should == {
      'name' => @foo.name,
      'foo' => { 
        'id' => @foo.id,
        'name' => @foo.name,
      },
      'href' => "http://test.org/foos/#{@foo.id}",
    }
  end

  describe "with configuration options" do

    before(:each) do
      Restful.api_prefix = 'prefix'
      Restful.model_configuration = {
        :foo => {
          :name => :fancy_name,
          :serialization => { :only => [:name], :methods => [:a_method] },
        }
      }
      @foo.save!
    end

    it "should take options from configuration" do
      rs = Restful::Serializer.new(@foo)
      rs.serialize.should == {
        'name' => @foo.fancy_name,
        'foo' => { 
          'name' => @foo.name,
          :a_method => @foo.a_method,
        },
        'href' => "http://test.org/prefix/foos/#{@foo.id}",
      }
    end
  
    it "should override options during initialization" do
      rs = Restful::Serializer.new(@foo, 
        :name => :name, 
        :serialization => { :only => [:id] }, 
        :url_for => :custom_foo
      )
      rs.serialize.should == {
        'name' => @foo.name,
        'foo' => { 
          'id' => @foo.id,
        },
        'href' => "http://test.org/custom_foo/#{@foo.id}",
      }
    end

  end

  describe "with associations" do

    before(:each) do
      Restful.model_configuration = {
        :foo => {
          :associations => :bars,
        },
        :bar => {
          :associations => { :special => :foo, :dingos => nil },
        },
      }
      generate_instances
    end

    it "should include references to associations" do
      rs = Restful::Serializer.new(@foo)
      rs.serialize.should == {
        'name' => @foo.name,
        'foo' => { 
          'id' => @foo.id,
          'name' => @foo.name,
        },
        'href' => "http://test.org/foos/#{@foo.id}",
        'bars_href' => "http://test.org/bars",
      }
    end

    it "should handle multiple and nested associations" do
      rs = Restful::Serializer.new(@bar1)
      rs.serialize.should == {
        'name' => @bar1.name,
        'bar' => { 
          'id' => @bar1.id,
          'name' => @bar1.name,
          'foo_id' => @bar1.foo_id,
        },
        'href' => "http://test.org/bars/#{@bar1.id}",
        'dingos_href' => "http://test.org/bars/#{@bar1.id}/dingos",
        'special_href' => "http://test.org/foos/#{@bar1.foo_id}",
      }
    end

  end

  describe "with subclasses" do
    
    before(:each) do
      Restful.model_configuration = {
        :thing => {
          :serialization => { :except => :secret }
        }
      }
      @thing = Thing.create!(:name => 'a thing', :secret => 'a secret')
      @sub = Sub.create!(:name => 'a sub thing', :secret => 'another secret')
    end

    it "should pull superclass configuration up into a subclass serialization" do
      rs = Restful::Serializer.new(@sub)
      rs.serialize.should == {
        'name' => @sub.name,
        'href' => "http://test.org/things/#{@sub.id}",
        'sub' => {
          'id' => @sub.id,
          'name' => @sub.name,
        }  
      }
    end
  end

  describe "with arrays" do
    before(:each) do
      Restful.model_configuration = {
        :foo => {
          :associations => :bars,
        },
        :bar => {
          :serialization => { :only => :name, :include => { :dingos => { :only =>  [ :name, :id] } } },
          :associations => [:foo, :dingos],
        },
      }
      generate_instances
    end

    it "should serialize arrays" do
      rs = Restful::Serializer.new(@foo.bars)
      rs.serialize.should == [
        {
          'name' => @bar1.name,
          'href' => "http://test.org/bars/#{@bar1.id}",
          'bar'  =>  {
            'name' => @bar1.name,
          },
        },
        {
          'name' => @bar2.name,
          'href' => "http://test.org/bars/#{@bar2.id}",
          'bar'  =>  {
            'name' => @bar2.name,
          },
        },
      ] 
    end

    it "should deeply serialize arrays if told to" do
      rs = Restful::Serializer.new(@foo.bars, :shallow => false)
      rs.serialize.should == [
        {
          'name' => @bar1.name,
          'bar'  =>  {
            'name' => @bar1.name,
            :dingos => [
              { 'name' => @dingo1.name, 'id' => @dingo1.id, }, 
              { 'name' => @dingo2.name, 'id' => @dingo2.id, }, 
            ],
          },
          'href' => "http://test.org/bars/#{@bar1.id}",
          'dingos_href' => "http://test.org/bars/#{@bar1.id}/dingos",
          'foo_href' => "http://test.org/foos/#{@bar1.foo_id}",
        },
        {
          'name' => @bar2.name,
          'bar'  =>  {
            'name' => @bar2.name,
            :dingos => [
              { 'name' => @dingo3.name, 'id' => @dingo3.id, }, 
              { 'name' => @dingo4.name, 'id' => @dingo4.id, }, 
            ],
          },
          'href' => "http://test.org/bars/#{@bar2.id}",
          'dingos_href' => "http://test.org/bars/#{@bar2.id}/dingos",
          'foo_href' => "http://test.org/foos/#{@bar2.foo_id}",
        },
      ] 
    end
  end

  it "should hook into activerecord" do
    @foo.save!
    @foo.should respond_to(:restful)
    @foo.restful(:serialization => { :only => :name }).should == {
      'name' => @foo.name,
      'foo' => { 
        'name' => @foo.name,
      },
      'href' => "http://test.org/foos/#{@foo.id}",
    }
  end

  it "Should hook into associations" do
    generate_instances
    @foo.bars.restful.should == [
      {
        "href" => "http://test.org/bars/#{@bar1.id}",
        "name" => @bar1.name,
        "bar" => {
          "name" => @bar1.name,
          "foo_id" => @bar1.foo_id,
          "id" => @bar1.id, 
        },
      },
      {
        "href" => "http://test.org/bars/#{@bar2.id}",
        "name" => @bar2.name,
        "bar" => {
          "name" => @bar2.name,
          "foo_id" => @bar2.foo_id,
          "id" => @bar2.id,
        },
      },
    ]
  end

  it "should work with AssociationProxy.respond_to" do
    pending('associations should respond_to :restful (AR 2.1 issue or AR issue in general?)') do
      @foo.bars.should respond_to(:restful)
    end
  end
end
