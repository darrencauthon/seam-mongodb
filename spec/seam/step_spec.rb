require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Seam::Step do
  describe "initialize" do
    it "should allow values to be set with the constructor" do
      step = Seam::Step.new( { id:   'an id',
                               name: 'a name',
                               type: 'a type',
                               arguments: ['1234', 2] } )
      step.id.must_equal 'an id'
      step.name.must_equal 'a name'
      step.type.must_equal 'a type'
      step.arguments.count.must_equal 2
      step.arguments[0].must_equal '1234'
      step.arguments[1].must_equal 2
    end
  end

  describe "to hash" do
    it "should allow values to be set with the constructor" do
      step = Seam::Step.new( { id:   'an id',
                               name: 'a name',
                               type: 'a type',
                               arguments: ['1234', 2] } )
      step = Seam::Step.new step.to_hash
      step.id.must_equal 'an id'
      step.name.must_equal 'a name'
      step.type.must_equal 'a type'
      step.arguments.count.must_equal 2
      step.arguments[0].must_equal '1234'
      step.arguments[1].must_equal 2
    end
  end
end
