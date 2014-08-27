class Reseller < ActiveRecord::Base
  attr_accessible :asr, :cost, :margin, :minutes, :name, :num_calls, :revenue, :id
  validates_uniqueness_of :id, :name
end
