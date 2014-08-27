class WeekTraffic < ActiveRecord::Base
  attr_accessible :id, :calldate, :calls, :cost, :margin, :minutes, :revenue, :name, :asr
  validates_uniqueness_of :id
end
