class Carrier < ActiveRecord::Base
  attr_accessible :id, :asr, :cost, :margin, :minutes, :name, :num_calls, :revenue
  validates_uniqueness_of :id
end
