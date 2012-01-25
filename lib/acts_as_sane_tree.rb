require 'acts_as_sane_tree/acts_as_sane_tree'
require 'acts_as_sane_tree/version'

if(defined?(ActiveRecord))
  ActiveRecord::Base.send :include, ActsAsSaneTree
  if(defined?(ActiveRecord::Relation))
    ActiveRecord::Relation.send :include, ActsAsSaneTree
  end
end
