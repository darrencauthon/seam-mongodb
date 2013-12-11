require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "worker" do

  before do
    Seam::Persistence.destroy
    @stamp_data_history = true
  end

  after do
    Timecop.return
  end

  describe "step" do
    it "should match the name" do
      worker = Seam::Worker.new
      worker.handles(:darren)
      worker.step.must_equal "darren"
    end
  end

  describe "move_to_next_step" do

    [:date].to_objects {[
      ['1/1/2011'],
      ['3/4/2015']
    ]}.each do |test|
      
      describe "move immediately" do

        before { Timecop.freeze Time.parse(test.date) }
        after  { Timecop.return }

        it "should move to the next step and set the date to now" do
          flow = Seam::Flow.new
          flow.apple
          flow.orange

          effort = flow.start( { first_name: 'John' } )
          effort = Seam::Effort.find(effort.id)

          effort.next_step.must_equal "apple"

          apple_worker = Seam::Worker.new
          apple_worker.handles(:apple)
          def apple_worker.process
            move_to_next_step
          end

          apple_worker.execute effort

          effort = Seam::Effort.find(effort.id)
          effort.next_step.must_equal "orange"
          effort.next_execute_at.must_equal Time.parse(test.date)
        end

      end

    end

    [:date, :next_date].to_objects {[
      ['1/1/2011', '2/1/2011'],
      ['1/1/2011', '2/2/2011'],
      ['3/4/2015', '4/5/2016']
    ]}.each do |test|

      describe "move to some point in the future" do

        before { Timecop.freeze Time.parse(test.date) }
        after  { Timecop.return }

        it "should move to the next step and set the date to now" do
          flow = Seam::Flow.new
          flow.apple
          flow.orange

          effort = flow.start( { first_name: 'John' } )
          effort = Seam::Effort.find(effort.id)

          effort.next_step.must_equal "apple"

          apple_worker = Seam::Worker.new
          apple_worker.handles(:apple)
          eval("
          def apple_worker.process
            move_to_next_step( { on: Time.parse('#{test.next_date}') } )
          end
          ")

          apple_worker.execute effort

          effort = Seam::Effort.find(effort.id)
          effort.next_step.must_equal "orange"
          effort.next_execute_at.must_equal Time.parse(test.next_date)
        end

      end

    end
  end

  describe "move_to_next_step as a default" do
    it "should go to move_to_next_step by default" do
      flow = Seam::Flow.new
      flow.apple
      flow.orange

      effort = flow.start( { first_name: 'John' } )
      effort = Seam::Effort.find(effort.id)

      effort.next_step.must_equal "apple"

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
      end

      apple_worker.execute effort

      effort = Seam::Effort.find(effort.id)
      effort.next_step.must_equal "orange"
    end
  end

  describe "try_again_in" do

    let(:effort) do
      flow = Seam::Flow.new
      flow.apple
      flow.orange

      e = flow.start( { first_name: 'John' } )
      Seam::Effort.find(e.id)
    end

    before do
      Timecop.freeze Time.parse('3/4/2013')
      effort.next_step.must_equal "apple"

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
        try_again_in 1.day
      end

      apple_worker.execute effort
    end

    it "should not update the next step" do
      fresh_effort = Seam::Effort.find(effort.id)
      fresh_effort.next_step.must_equal "apple"
    end

    it "should update the next execute date" do
      fresh_effort = Seam::Effort.find(effort.id)
      fresh_effort.next_execute_at.must_equal Time.parse('4/4/2013')
    end
  end

  describe "try_again_on" do

    describe "putting it off for one day" do
      let(:effort) do
        flow = Seam::Flow.new
        flow.apple
        flow.orange

        e = flow.start( { first_name: 'John' } )
        Seam::Effort.find(e.id)
      end

      before do
        Timecop.freeze Time.parse('3/4/2013')
        effort.next_step.must_equal "apple"

        apple_worker = Seam::Worker.new
        apple_worker.handles(:apple)
        def apple_worker.process
          try_again_on Time.parse('4/4/2013')
        end

        apple_worker.execute effort
      end

      it "should not update the next step" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.next_step.must_equal "apple"
      end

      it "should update the next execute date" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.next_execute_at.must_equal Time.parse('4/4/2013')
      end

      it "should update the history" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history[0]['try_again_on'].must_equal Time.parse('4/4/2013')
      end
    end
  end

  describe "more copmlex example" do

    let(:effort1) do
      flow = Seam::Flow.new
      flow.grape
      flow.mango

      e = flow.start( { status: 'Good' } )
      Seam::Effort.find(e.id)
    end
    
    let(:effort2) do
      flow = Seam::Flow.new
      flow.grape
      flow.mango

      e = flow.start( { status: 'Bad' } )
      Seam::Effort.find(e.id)
    end

    before do
      Timecop.freeze Time.parse('1/6/2013')

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
        if @current_effort.data[:status] == 'Good'
          move_to_next_step
        else
          try_again_in 1.day
        end
      end

      apple_worker.execute effort1
      apple_worker.execute effort2
    end

    it "should move the first effort forward" do
      fresh_effort = Seam::Effort.find(effort1.id)
      fresh_effort.next_step.must_equal "mango"
    end

    it "should keep the second effort at the same step" do
      fresh_effort = Seam::Effort.find(effort2.id)
      fresh_effort.next_step.must_equal "grape"
      fresh_effort.next_execute_at.must_equal Time.parse('2/6/2013')
    end
  end

  describe "processing all pending steps for one effort" do
    let(:effort1_creator) do
      ->() do
        flow = Seam::Flow.new
        flow.banana
        flow.mango

        e = flow.start
        Seam::Effort.find(e.id)
      end
    end
    
    let(:effort2_creator) do
      ->() do
        flow = Seam::Flow.new
        flow.apple
        flow.orange

        e = flow.start
        Seam::Effort.find(e.id)
      end
    end

    let(:apple_worker) do
      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)

      apple_worker.class_eval do
        attr_accessor :count
      end

      def apple_worker.process
        self.count += 1
      end

      apple_worker.count = 0
      apple_worker
    end

    before do
      Timecop.freeze Time.parse('1/6/2013')

      effort1_creator.call
      effort1_creator.call
      effort1_creator.call
      effort2_creator.call
      effort2_creator.call

      apple_worker.execute_all
    end

    it "should call the apple worker for the record in question" do
      apple_worker.count.must_equal 2
    end
  end

  describe "a more realistic example" do

    let(:flow) do
      flow = Seam::Flow.new
      flow.wait_for_attempting_contact_stage
      flow.determine_if_postcard_should_be_sent
      flow.send_postcard_if_necessary
      flow
    end

    let(:effort_creator) do
      ->() do
        e = flow.start
        flow.stamp_data_history = @stamp_data_history
        Seam::Effort.find(e.id)
      end
    end
    
    let(:wait_for_attempting_contact_stage_worker) do
      worker = Seam::Worker.new
      worker.handles(:wait_for_attempting_contact_stage)

      def worker.process
        @current_effort.data['hit 1'] ||= 0
        @current_effort.data['hit 1'] += 1
        move_to_next_step
      end

      worker
    end

    let(:determine_if_postcard_should_be_sent_worker) do
      worker = Seam::Worker.new
      worker.handles(:determine_if_postcard_should_be_sent)

      def worker.process
        @current_effort.data['hit 2'] ||= 0
        @current_effort.data['hit 2'] += 1
        move_to_next_step
      end

      worker
    end

    let(:send_postcard_if_necessary_worker) do
      worker = Seam::Worker.new
      worker.handles(:send_postcard_if_necessary)

      def worker.process
        @current_effort.data['hit 3'] ||= 0
        @current_effort.data['hit 3'] += 1
        move_to_next_step
      end

      worker
    end

    before do
      Timecop.freeze Time.parse('1/6/2013')
    end

    it "should progress through the story" do

      # SETUP
      effort = effort_creator.call
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      # FIRST WAVE
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "determine_if_postcard_should_be_sent"

      effort.complete?.must_equal false

      # SECOND WAVE
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "send_postcard_if_necessary"

      # THIRD WAVE
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal nil

      effort.data['hit 1'].must_equal 1
      effort.data['hit 2'].must_equal 1
      effort.data['hit 3'].must_equal 1

      effort.complete?.must_equal true
      effort.completed_at.must_equal Time.now
      
      # FUTURE WAVES
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal nil

      effort.data['hit 1'].must_equal 1
      effort.data['hit 2'].must_equal 1
      effort.data['hit 3'].must_equal 1

    end
  end

  describe "a more realistic example with waiting" do

    let(:flow) do
      flow = Seam::Flow.new
      flow.wait_for_attempting_contact_stage
      flow.determine_if_postcard_should_be_sent
      flow.send_postcard_if_necessary
      flow
    end

    let(:effort_creator) do
      ->() do
        e = flow.start
        Seam::Effort.find(e.id)
      end
    end
    
    let(:wait_for_attempting_contact_stage_worker) do
      worker = Seam::Worker.new
      worker.handles(:wait_for_attempting_contact_stage)

      def worker.process
        @current_effort.data['hit 1'] ||= 0
        @current_effort.data['hit 1'] += 1
        if Time.now >= Time.parse('28/12/2013')
          move_to_next_step
        else
          try_again_in 1.day
        end
      end

      worker
    end

    let(:determine_if_postcard_should_be_sent_worker) do
      worker = Seam::Worker.new
      worker.handles(:determine_if_postcard_should_be_sent)

      def worker.process
        @current_effort.data['hit 2'] ||= 0
        @current_effort.data['hit 2'] += 1
        move_to_next_step
      end

      worker
    end

    let(:send_postcard_if_necessary_worker) do
      worker = Seam::Worker.new
      worker.handles(:send_postcard_if_necessary)

      def worker.process
        @current_effort.data['hit 3'] ||= 0
        @current_effort.data['hit 3'] += 1
        move_to_next_step
      end

      worker
    end

    before do
      Timecop.freeze Time.parse('25/12/2013')
    end

    it "should progress through the story" do

      # SETUP
      effort = effort_creator.call
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      # FIRST DAY
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      Timecop.freeze Time.parse('29/12/2013')

      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "determine_if_postcard_should_be_sent"
      effort.data['hit 1'].must_equal 2
    end
  end

  describe "tracking history" do

    let(:flow) do
      flow = Seam::Flow.new
      flow.wait_for_attempting_contact_stage
      flow.determine_if_postcard_should_be_sent
      flow.send_postcard_if_necessary
      flow
    end

    let(:effort_creator) do
      ->(values = {}) do
        e = flow.start values
        Seam::Effort.find(e.id)
      end
    end
    
    let(:wait_for_attempting_contact_stage_worker) do
      worker = Seam::Worker.new
      worker.handles(:wait_for_attempting_contact_stage)

      def worker.process
        @current_effort.data['hit 1'] ||= 0
        @current_effort.data['hit 1'] += 1
        if Time.now >= Time.parse('28/12/2013')
          move_to_next_step
        else
          try_again_in 1.day
        end
      end

      worker
    end

    let(:determine_if_postcard_should_be_sent_worker) do
      worker = Seam::Worker.new
      worker.handles(:determine_if_postcard_should_be_sent)

      def worker.process
        @current_effort.data['hit 2'] ||= 0
        @current_effort.data['hit 2'] += 1
        move_to_next_step
      end

      worker
    end

    let(:send_postcard_if_necessary_worker) do
      worker = Seam::Worker.new
      worker.handles(:send_postcard_if_necessary)

      def worker.process
        @current_effort.data['hit 3'] ||= 0
        @current_effort.data['hit 3'] += 1
        move_to_next_step
      end

      worker
    end

    before do
      Timecop.freeze Time.parse('26/12/2013')
    end

    it "should progress through the story" do

      # SETUP
      effort = effort_creator.call({ first_name: 'DARREN' })
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      # FIRST DAY
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      effort.history.count.must_equal 1
      effort.history[0].contrast_with!( {
                                          "step_id" => effort.flow['steps'][0]['id'],
                                          "started_at"=> Time.now, 
                                          "step"=>"wait_for_attempting_contact_stage",
                                          "stopped_at" => Time.now, 
                                        } )

      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      effort.history.count.must_equal 1
      effort.history[0].contrast_with!( {
                                          "step_id" => effort.flow['steps'][0]['id'],
                                          "started_at"=> Time.now,
                                          "step"=>"wait_for_attempting_contact_stage",
                                          "stopped_at" => Time.now,
                                          "result" => "try_again_in",
                                          "try_again_on" => Time.now + 1.day 
                                        } )

      # THE NEXT DAY
      Timecop.freeze Time.parse('27/12/2013')

      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "wait_for_attempting_contact_stage"

      effort.history.count.must_equal 2
      effort.history[1].contrast_with!( {
                                          "step_id" => effort.flow['steps'][0]['id'],
                                          "started_at"=> Time.now, 
                                          "step"=>"wait_for_attempting_contact_stage",
                                          "stopped_at" => Time.now,
                                          "result" => "try_again_in" 
                                        } )

      # THE NEXT DAY
      Timecop.freeze Time.parse('28/12/2013')

      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all

      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "determine_if_postcard_should_be_sent"

      effort.history.count.must_equal 3
      effort.history[2].contrast_with!( { 
                                          "step_id" => effort.flow['steps'][0]['id'],
                                          "started_at"=> Time.now,
                                          "step"=>"wait_for_attempting_contact_stage",
                                          "stopped_at" => Time.now,
                                          "result" => "move_to_next_step" 
                                        } )

      # KEEP GOING
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal "send_postcard_if_necessary"

      effort.history.count.must_equal 4
      effort.history[3].contrast_with!( { 
                                          "step_id" => effort.flow['steps'][1]['id'],
                                          "started_at"=> Time.now,
                                          "step"=>"determine_if_postcard_should_be_sent",
                                          "stopped_at" => Time.now,
                                          "result" => "move_to_next_step" 
                                        } )
      
      # KEEP GOING
      send_postcard_if_necessary_worker.execute_all
      determine_if_postcard_should_be_sent_worker.execute_all
      wait_for_attempting_contact_stage_worker.execute_all
      effort = Seam::Effort.find effort.id
      effort.next_step.must_equal nil

      effort.history.count.must_equal 5
      effort.history[4].contrast_with!( {
                                          "step_id" => effort.flow['steps'][2]['id'],
                                          "started_at"=> Time.now,
                                          "step"=>"send_postcard_if_necessary",
                                          "stopped_at" => Time.now,
                                          "result" => "move_to_next_step" 
                                        } )
    end
  end

  describe "eject" do

    let(:effort) do
      flow = Seam::Flow.new
      flow.apple
      flow.orange

      e = flow.start( { first_name: 'John' } )
      Seam::Effort.find(e.id)
    end

    before do
      Timecop.freeze Time.parse('5/11/2013')
      effort.next_step.must_equal "apple"

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
        eject
      end

      apple_worker.execute effort
    end

    it "should mark the step as completed" do
      fresh_effort = Seam::Effort.find(effort.id)
      fresh_effort.complete?.must_equal true
    end

    it "should mark the next step to nil" do
      fresh_effort = Seam::Effort.find(effort.id)
      fresh_effort.next_step.nil?.must_equal true
    end

    it "should mark the completed_at date" do
      fresh_effort = Seam::Effort.find(effort.id)
      fresh_effort.completed_at.must_equal Time.now
    end
    
    it "should mark the history" do
      effort.history[0].contrast_with!({"step"=>"apple", "result" => "eject" } )
    end

  end

  describe "use the name of the worker to tie to a step" do

    let(:effort) do
      flow = Seam::Flow.new
      flow.i_will_not_call_handles

      e = flow.start
      Seam::Effort.find(e.id)
    end

    before do
      effort
      worker = IWillNotCallHandlesWorker.new
      IWillNotCallHandlesWorker.new.execute_all
    end

    it "should complete the effort" do
      fresh_effort = Seam::Effort.find effort.id
      fresh_effort.complete?.must_equal true
    end

  end

  describe "making the current step available" do
    it "should return the first step if on the first step" do
      flow = Seam::Flow.new
      flow.apple("test")
      flow.orange

      effort = flow.start( { first_name: 'John' } )
      effort = Seam::Effort.find(effort.id)

      effort.next_step.must_equal "apple"

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
        current_step.nil?.must_equal false
        current_step["name"].must_equal "apple"
        current_step["arguments"].must_equal ["test"]
      end

      apple_worker.execute effort
    end

    it "should return the second step if on the second step" do
      flow = Seam::Flow.new
      flow.apple("test")
      flow.orange("another test")

      effort = flow.start( { first_name: 'John' } )
      effort = Seam::Effort.find(effort.id)

      effort.next_step.must_equal "apple"

      apple_worker = Seam::Worker.new
      apple_worker.handles(:apple)
      def apple_worker.process
        current_step.nil?.must_equal false
        current_step["name"].must_equal "apple"
        current_step["arguments"].must_equal ["test"]
      end

      orange_worker = Seam::Worker.new
      orange_worker.handles(:orange)
      def orange_worker.process
        current_step.nil?.must_equal false
        current_step["name"].must_equal "orange"
        current_step["arguments"].must_equal ["another test"]
      end

      apple_worker.execute_all
      orange_worker.execute_all
    end
  end

  describe "data history" do
    describe "stamping the history" do
      let(:effort) do
        flow = Seam::Flow.new
        flow.stamp_data_history = true
        flow.apple

        e = flow.start( { first_name: 'John' } )
        Seam::Effort.find(e.id)
      end

      before do
        Timecop.freeze Time.parse('3/4/2013')
        effort.next_step.must_equal "apple"

        apple_worker = Seam::Worker.new
        apple_worker.handles(:apple)
        def apple_worker.process
          effort.data['something'] = 'else'
        end

        apple_worker.execute effort
      end

      it "should not update the next step" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.count.must_equal 1
      end

      it "should set the data_before history" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.first["data_before"].must_equal( { "first_name" => 'John' } )
      end

      it "should set the data_after history" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.first["data_after"].must_equal( { "first_name" => 'John', "something" => 'else' } )
      end
    end

    describe "not stamping the history" do
      let(:effort) do
        flow = Seam::Flow.new
        flow.stamp_data_history = false
        flow.apple

        e = flow.start( { first_name: 'John' } )
        Seam::Effort.find(e.id)
      end

      before do
        Timecop.freeze Time.parse('3/4/2013')

        apple_worker = Seam::Worker.new
        apple_worker.handles(:apple)
        def apple_worker.process
          effort.data['something'] = 'else'
        end

        apple_worker.execute effort
      end

      it "should not update the next step" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.count.must_equal 1
      end

      it "should set the data_before history" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.first["data_before"].nil?.must_equal true
      end

      it "should set the data_after history" do
        fresh_effort = Seam::Effort.find(effort.id)
        fresh_effort.history.first["data_after"].nil?.must_equal true
      end
    end
  end
end

class IWillNotCallHandlesWorker < Seam::Worker
  # no calling handles here
  def process; end
end
