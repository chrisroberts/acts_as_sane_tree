$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'lib/version'
Gem::Specification.new do |s|
  s.name = 'acts_as_sane_tree'
  s.version = ActsAsSaneTree::VERSION
  s.summary = 'Sane tree builder for ActiveRecord and Postgresql'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/chrisroberts/acts_as_sane_tree'
  s.description = 'Sane ActiveRecord tree builder'
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc']
  s.add_dependency 'activerecord', '> 0'
  s.files = %w{
acts_as_sane_tree.gemspec
init.rb
README.rdoc
CHANGELOG.rdoc
lib/acts_as_sane_tree.rb
lib/version.rb
}
end
