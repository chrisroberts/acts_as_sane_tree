require 'acts_as_sane_tree/acts_as_sane_tree'
require 'acts_as_sane_tree/version'

if(defined?(Rails))
  ActiveRecord::Base.send :include, ActsAsSaneTree
end
