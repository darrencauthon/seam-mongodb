require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Seam do

  before do
    Seam::Persistence.destroy
  end

  describe "steps to run" do

    it "should return an empty array if nothing has happened" do
      Seam.steps_to_run.count.must_equal 0
    end

    it "should return step x if step x is next" do
      flow = Seam::Flow.new
      flow.x
      flow.y
      flow.start

      Seam.steps_to_run.include?('x').must_equal true
    end

    it "should return step y if step y is next" do
      flow = Seam::Flow.new
      flow.y
      flow.x
      flow.start

      Seam.steps_to_run.include?('y').must_equal true
    end

    it "should return step x or y if step x and y are next" do
      flow = Seam::Flow.new
      flow.y
      flow.start

      flow = Seam::Flow.new
      flow.x
      flow.start

      (['x', 'y'].select { |x| Seam.steps_to_run.include?(x) }.count > 0).must_equal true
    end

  end

end
