require 'seam'
require "seam/mongodb/version"
require 'moped'
require 'subtle'

module Seam
  module Mongodb

    def self.collection
      @collection
    end

    def self.set_collection collection
      @collection = collection
      overwrite_the_persistence_layer
    end

    def self.overwrite_the_persistence_layer
      Seam::Persistence.class_eval do
        def self.find_by_effort_id effort_id
          document = Seam::Mongodb.collection.find( { id: effort_id } ).first
          return nil unless document
          Seam::Effort.parse document
        end

        def self.find_all_pending_executions_by_step step
          Seam::Mongodb.collection
            .find( { next_step: step, next_execute_at: { '$lte' => Time.now } } )
            .select( { '_id' => 1 } )
            .map do |x|
              -> do
                record = Seam::Mongodb.collection.find( { '_id' => x['_id'] } ).first
                Seam::Effort.parse record
              end.to_object
            end
        end

        def self.save effort
          Seam::Mongodb.collection
              .find( { id: effort.id } )
              .update("$set" => effort.to_hash)
        end

        def self.create effort
          Seam::Mongodb.collection.insert(effort.to_hash)
        end

        def self.all
          Seam::Mongodb.collection.find.to_a
        end

        def self.destroy
          Seam::Mongodb.collection.drop
        end
      end
    end
  end
end

