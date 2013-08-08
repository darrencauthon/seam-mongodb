require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Seam::Effort do
  before do
    Seam::Persistence.destroy
  end

  let(:flow) do
    f = Seam::Flow.new
    f.step1
    f.step2
    f
  end

  describe "updating an effort" do
    it "should not create another document in the collection" do
      first_effort = flow.start
      Seam::Persistence.all.count.must_equal 1
      first_effort.save
      Seam::Persistence.all.count.must_equal 1

      second_effort = flow.start
      Seam::Persistence.all.count.must_equal 2
      second_effort.save
      Seam::Persistence.all.count.must_equal 2
    end

    it "should update the information" do
      first_effort = flow.start
      second_effort = flow.start

      first_effort.next_step = 'i_changed_the_first_one'
      first_effort.save
      first_effort.to_hash.contrast_with! Seam::Effort.find(first_effort.id).to_hash, [:id, :created_at]
      second_effort.to_hash.contrast_with! Seam::Effort.find(second_effort.id).to_hash, [:id, :created_at]

      second_effort.next_step = 'i_changed_the_second_one'
      second_effort.save
      first_effort.to_hash.contrast_with! Seam::Effort.find(first_effort.id).to_hash, [:id, :created_at]
      second_effort.to_hash.contrast_with! Seam::Effort.find(second_effort.id).to_hash, [:id, :created_at]
    end
  end
end
