require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class DoSomething < Seam::Worker
  def process
  end
end

describe Seam::WaitWorker do

  it "should be a worker" do
    Seam::WaitWorker.new.is_a? Seam::Worker
  end

  it "should handle the wait step" do
    Seam::WaitWorker.new.step.must_equal 'wait'
  end

  let(:today) do
    Time.parse '1/1/2011'
  end

  let(:effort_id) do
    effort = flow.start
    effort.id
  end

  describe "using it in a flow" do

    [:length_of_time].to_objects { [
      [3.days],
      [1.day],
      [30.minutes]
    ] }.each do |test|

      describe "a simple situation" do

        let(:flow) do
          f = Seam::Flow.new
          f.wait test.length_of_time
          f.do_something
          f
        end

        before do
          Timecop.freeze today
          effort_id
        end

        it "should move to the next step" do
          Seam::WaitWorker.new.execute_all
          Seam::Effort.find(effort_id).next_step.must_equal "do_something"
        end
        j
        it "should set the next execute date" do
          Seam::WaitWorker.new.execute_all
          Seam::Effort.find(effort_id).next_execute_at.must_equal (today + test.length_of_time)
        end

      end

    end

    describe "time has passed since the flow was started and the wait worker was called" do

      let(:today)                              { Time.parse('1/1/2011') }
      let(:time_to_wait)                       { 3.days }
      let(:time_before_wait_worker_was_called) { 1.day }
      let(:expected_start)                     { today + time_to_wait }

      let(:flow) do
        f = Seam::Flow.new
        f.wait time_to_wait
        f.do_something
        f
      end

      before do
        Timecop.freeze today
        effort_id

        Timecop.freeze today + time_before_wait_worker_was_called
      end

      it "should move to the next step" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_step.must_equal "do_something"
      end
       
      it "should set the next execute date" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_execute_at.must_equal expected_start
      end

    end

    describe "time has passed since the last step was started and the wait worker was called" do

      let(:today)                              { Time.parse('1/1/2011') }
      let(:time_to_wait)                       { 8.days }
      let(:time_it_took_for_previous_step)     { 1.days }
      let(:time_before_wait_worker_was_called) { 3.day }
      let(:expected_start)                     { today + time_to_wait + time_it_took_for_previous_step }

      let(:flow) do
        f = Seam::Flow.new
        f.do_something
        f.wait time_to_wait
        f.do_something
        f
      end

      before do
        Timecop.freeze today
        effort_id

        Timecop.freeze Time.now + time_it_took_for_previous_step
        DoSomething.new.execute_all
        Timecop.freeze Time.now + time_before_wait_worker_was_called
      end

      it "should move to the next step" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_step.must_equal "do_something"
      end
       
      it "should set the next execute date" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_execute_at.must_equal expected_start
      end

    end
    j
    describe "a more complex example of waiting" do

      let(:today)                              { Time.parse('1/1/2011') }
      let(:time_to_wait)                       { 8.days }
      let(:time_it_took_for_first_step)        { 1.days }
      let(:time_it_took_for_second_step)       { 4.days }
      let(:time_before_wait_worker_was_called) { 3.day }
      let(:expected_start)                     { today + 
                                                 time_to_wait + 
                                                 time_it_took_for_first_step +
                                                 time_it_took_for_second_step  }

      let(:flow) do
        f = Seam::Flow.new
        f.do_something
        f.do_something
        f.wait time_to_wait
        f.do_something
        f
      end

      before do
        Timecop.freeze today
        effort_id

        Timecop.freeze Time.now + time_it_took_for_first_step
        DoSomething.new.execute_all
        Timecop.freeze Time.now + time_it_took_for_second_step
        DoSomething.new.execute_all
        Timecop.freeze Time.now + time_before_wait_worker_was_called
      end

      it "should move to the next step" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_step.must_equal "do_something"
      end
       
      it "should set the next execute date" do
        Seam::WaitWorker.new.execute_all
        Seam::Effort.find(effort_id).next_execute_at.must_equal expected_start
      end

    end
    
  end

end
