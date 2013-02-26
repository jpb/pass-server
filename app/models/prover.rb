# == Schema Information
#
# Table name: provers
#
#  id             :integer          not null, primary key
#  public_key     :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  device_type_id :integer
#  name           :string(255)
#

class Prover < ActiveRecord::Base
  attr_accessible :public_key

  belongs_to :device_type
  belongs_to :session

  validates :public_key, :device_type_id, :presence => true
  validates_associated :device_type
end
