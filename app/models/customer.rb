class Customer < ActiveRecord::Base
  attr_accessible :id, :cost, :margin, :minutes, :name, :revenue, :num_calls, :asr
  validates_uniqueness_of :id
end
