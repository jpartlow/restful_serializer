require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

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
    Restful.default_url_options = { :host => 'test.org' }
  end

  after(:each) do
    Restful.clear
  end

  def check_routing
    ActionController::Routing::Routes.routes.size.should == 30
    by_method = ActionController::Routing::Routes.routes.group_by { |r|
      r.conditions[:method]
    }
#    ActionController::Routing::Routes.routes.each { |r| puts r }
    by_method[:get].size.should == 4 * 4
    by_method[:put].size.should == 4
    by_method[:post].size.should == 4
    by_method[:delete].size.should == 4
    by_method[nil].size.should == 2
  end

  it "should not interfere with resource route generation" do
    check_routing
  end

  it "should not interfere with resource route generation if we configure webservices" do
    Restful.register_web_service('test',
      :resources => {
        :foo => { :serialization => { :only => :id } },
      }
    )
    check_routing
  end

  describe "with an empty web service" do

    before(:each) do
      @empty_ws = Restful.register_web_service('empty')
    end

    it "should require a subject and a web service" do
      lambda { Restful::Serializer.new }.should raise_error(ArgumentError)
      lambda { Restful::Serializer.new('foo') }.should raise_error(ArgumentError)
      Restful::Serializer.new('foo', @empty_ws).should be_kind_of(Restful::Serializer)
    end
  
    it "should set klass" do
      rs = Restful::Serializer.new(@foo, @empty_ws)
      rs.klass.should == 'foo'
    end
  
    it "should serialize" do
      @foo.save!
      rs = Restful::Serializer.new(@foo, @empty_ws)
      rs.serialize.should == {
        'name' => @foo.name,
        'foo' => { 
          'id' => @foo.id,
          'name' => @foo.name,
        },
        'href' => "http://test.org/foos/#{@foo.id}",
      }
    end
  end

  describe "with configuration options" do

    before(:each) do
      Restful.register_web_service('test',
        :api_prefix => 'prefix',
        :resources => {
          :foo => {
            :name_method => :fancy_name,
            :serialization => { :only => [:name], :methods => [:a_method] },
          }
        }
      )
      @test_ws = Restful.web_service_configuration('test')
      @foo.save!
    end

    it "should take options from configuration" do
      rs = Restful::Serializer.new(@foo, @test_ws)
      rs.serialize.should == {
        'name' => @foo.fancy_name,
        'foo' => { 
          'name' => @foo.name,
          'a_method' => @foo.a_method,
        },
        'href' => "http://test.org/prefix/foos/#{@foo.id}",
      }
    end
  
    it "should merge options during initialization" do
      rs = Restful::Serializer.new(@foo, @test_ws,
        :name_method => :name, 
        :serialization => { :only => [:id] }, 
        :url_for => :custom_foo
      )
      rs.serialize.should == {
        'name' => @foo.name,
        'foo' => { 
          'id' => @foo.id,
          'name' => @foo.name,
          'a_method' => @foo.a_method,
        },
        'href' => "http://test.org/custom_foo/#{@foo.id}",
      }
    end

    it "should provide fine grained configuration" do
      rs = Restful::Serializer.new(@foo, @test_ws) do |config|
        config.url_for = nil
        config.serialization.only = :id
        config.serialization.methods.clear
      end
      rs.serialize.should == {
        'name' => @foo.fancy_name,
        'foo' => { 
          'id' => @foo.id,
        },
        'href' => "http://test.org/prefix/foos/#{@foo.id}",
      }
    end
  end

  describe "with associations" do

    before(:each) do
      Restful.register_web_service('test',
        :resources => {
          :foo => {
            :associations => :bars,
          },
          :bar => {
            :associations => { :special => :foo, :dingos => nil },
          },
        }
      )
      @test_ws = Restful.web_service_configuration('test')
      generate_instances
    end

    it "should include references to associations" do
      rs = Restful::Serializer.new(@foo, @test_ws)
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
      rs = Restful::Serializer.new(@bar1, @test_ws)
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
      Restful.register_web_service('test',
        :resources => {
          :thing => {
            :serialization => { :except => :secret }
          }
        }
      )
      @test_ws = Restful.web_service_configuration('test')
      @thing = Thing.create!(:name => 'a thing', :secret => 'a secret')
      @sub = Sub.create!(:name => 'a sub thing', :secret => 'another secret')
    end

    it "should pull superclass configuration up into a subclass serialization" do
      rs = Restful::Serializer.new(@sub, @test_ws)
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
      Restful.register_web_service('test',
        :resources => {
          :foo => {
            :associations => :bars,
          },
          :bar => {
            :serialization => { :only => [:name], :include => { :dingos => { :only =>  [ :name, :id] } } },
            :associations => [:foo, :dingos],
          },
        }
      )
      @test_ws = Restful.web_service_configuration('test')
      generate_instances
    end

    it "should serialize arrays" do
      rs = Restful::Serializer.new(@foo.bars, @test_ws)
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
      rs = Restful::Serializer.new(@foo.bars, @test_ws, :shallow => false)
      rs.serialize.should == [
        {
          'name' => @bar1.name,
          'bar'  =>  {
            'name' => @bar1.name,
            'dingos' => [
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
            'dingos' => [
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

    it "should merge options during initialization for each member" do
      rs = Restful::Serializer.new(@foo.bars, @test_ws,
        :serialization => { :only => :id } 
      )
      rs.serialize.should == [
        {
          'name' => @bar1.name,
          'href' => "http://test.org/bars/#{@bar1.id}",
          'bar'  =>  {
            'name' => @bar1.name,
            'id'   => @bar1.id,
          },
        },
        {
          'name' => @bar2.name,
          'href' => "http://test.org/bars/#{@bar2.id}",
          'bar'  =>  {
            'name' => @bar2.name,
            'id'   => @bar2.id,
          },
        },
      ] 
    end

    it "should provide fine grained configuration for each member" do
      rs = Restful::Serializer.new(@foo.bars, @test_ws) do |configure|
        configure.serialization.only =  :id
      end
      rs.serialize.should == [
        {
          'name' => @bar1.name,
          'href' => "http://test.org/bars/#{@bar1.id}",
          'bar'  =>  {
            'id' => @bar1.id,
          },
        },
        {
          'name' => @bar2.name,
          'href' => "http://test.org/bars/#{@bar2.id}",
          'bar'  =>  {
            'id' => @bar2.id,
          },
        },
      ] 
    end
  end

  describe "extensions" do
    
    before(:each) do
      Restful.register_web_service('test',
        :resources => {
          :foo => {
            :serialization => { :only => :name },
            :associations => :bars,
          },
          :bar => {
            :serialization => { :only => [:name], :include => { :dingos => { :only =>  [ :name, :id] } } },
            :associations => [:foo, :dingos],
          },
        }
      )
      @test_ws = Restful.web_service_configuration('test')
      generate_instances
    end

    it "should hook into activerecord" do
      @foo.should respond_to(:restful)
      result = @foo.restful('test', :serialization => { :only => [:id] })
      result.should == {
        'name' => @foo.name,
        'foo' => { 
          'name' => @foo.name,
          'id' => @foo.id,
        },
        'href' => "http://test.org/foos/#{@foo.id}",
        'bars_href' => "http://test.org/bars",
      }
      # test default web service
      @foo.restful(:serialization => {:only => :id}).should == result
    end
  
    it "should hook into associations" do
      result = @foo.bars.restful('test') do |configure|
        configure.serialization.only = []
      end

      result.should == [
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

      @foo.bars.to_a.restful('test') do |configure|
        configure.serialization.only = []
      end.should == result
    end

  end

  it "should work with AssociationProxy.respond_to" do
    @foo.bars.should respond_to(:restful)
  end

  it "should extend ActiveRecord" do
    @foo.should respond_to(:restful)
  end

  it "should extend Array" do
    [].should respond_to(:restful)
  end

end

describe Restful::DeepHash do
  it "should deeply stringify keys" do
    h = Restful::DeepHash[
      :foo => {
        :bar => 1
      },
      :members => [
        { :id => 1 },
        { :id => 2 },
      ]
    ]
    h2 = h.deeply_stringify_keys!
    h.should == {
      'foo' => {
        'bar' => 1,
      },
      'members' => [
        { 'id' => 1 },
        { 'id' => 2 },
      ],
    }
    h.should equal(h2)
  end
end

