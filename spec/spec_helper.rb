require File.expand_path(File.dirname(__FILE__) + '/../lib/seam/mongodb')
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require 'subtle'
require 'timecop'
require 'contrast'
require 'mocha/setup'

def test_moped_session
  session = Moped::Session.new([ "127.0.0.1:27017" ])
  session.use "seam_test"
end

Seam::Mongodb.set_collection test_moped_session['test_efforts']
