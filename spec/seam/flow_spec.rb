require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "flow" do
  before do
    Seam::Persistence.destroy
  end

  after do
    Timecop.return
  end

  describe "a useful example" do
    let(:flow) do
      f = Seam::Flow.new
      f.wait_for_attempting_contact_stage limit: 2.weeks
      f.determine_if_postcard_should_be_sent
      f.send_postcard_if_necessary
      f
    end

    describe "steps that must be taken" do
      before do
        flow
      end

      it "should not throw an error" do
        flow.steps.count.must_equal 3
      end

      it "should set the name of the three steps" do
        flow.steps[0].name.must_equal "wait_for_attempting_contact_stage"
        flow.steps[1].name.must_equal "determine_if_postcard_should_be_sent"
        flow.steps[2].name.must_equal "send_postcard_if_necessary"
      end

      it "should set the step types of the three steps" do
        flow.steps[0].type.must_equal "do"
        flow.steps[1].type.must_equal "do"
        flow.steps[2].type.must_equal "do"
      end
      
      it "should set the arguments as well" do
        flow.steps[0].arguments.must_equal [{ limit: 14.days.to_i }]
        flow.steps[1].arguments.must_equal []
        flow.steps[2].arguments.must_equal []
      end
    end
  end

  describe "a more useful example" do

    describe "starting an effort" do
      let(:flow) do
        flow = Seam::Flow.new
        flow.do_something
        flow.do_something_else
        flow
      end

      let(:now) { Time.parse('1/1/2011') }

      before do
        Timecop.freeze now

        @expected_uuid = SecureRandom.uuid.to_s
        SecureRandom.expects(:uuid).returns @expected_uuid

        @effort = flow.start( { first_name: 'John' } )
      end

      it "should mark no steps as completed" do
        @effort.completed_steps.count.must_equal 0
      end

      it "should stamp the effort with a uuid" do
        @effort.id.must_equal @expected_uuid
      end

      it "should stamp the create date" do
        @effort.created_at.must_equal now
      end

      it "should stamp the next execute date" do
        @effort.next_execute_at.must_equal now
      end

      it "should stamp the next step name" do
        @effort.next_step.must_equal "do_something"
      end

      it "should save an effort in the db" do
        effort = Seam::Effort.find @effort.id
        effort.to_hash.contrast_with! @effort.to_hash, [:id, :created_at]
      end
    end
  end
end
