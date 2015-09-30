class KeyPair < ActiveRecord::Base
  belongs_to :compute_resource
  include AccessibleAttributes

  validates_lengths_from_database
  validates :name, :secret, :presence => true
  validates :compute_resource_id, :presence => true, :uniqueness => true

  def skip_strip_attrs
    ['secret']
  end
end
