require 'rubygems'
require 'bundler/setup'
require 'pg'
require 'active_record'
require 'active_record/migration'
require 'benchmark'
require 'acts_as_sane_tree'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  :adapter => 'postgresql',
  :database => 'tree_test',
  :username => 'postgres'
)

class Node < ActiveRecord::Base
  acts_as_sane_tree
  validates_uniqueness_of :name
  validates_uniqueness_of :parent_id, :scope => :id
end

class NodeSetup < ActiveRecord::Migration
  class << self
    def up
      create_table :nodes do |t|
        t.text :name
        t.integer :parent_id
      end
      add_index :nodes, [:parent_id, :id], :unique => true
    end
  end
end

# Quick and dirty database scrubbing
if(Node.table_exists?)
  ActiveRecord::Base.connection.execute "drop schema public cascade"
  ActiveRecord::Base.connection.execute "create schema public"
end

NodeSetup.up

# Create three root nodes with 50 descendants
# Descendants should branch randomly

nodes = []

3.times do |i|
  nodes[i] = []
  parent = Node.create(:name => "root_#{i}")
  50.times do |j|
    node = Node.new(:name => "node_#{i}_#{j}")
    _parent = nodes[i][rand(nodes[i].size)] || parent
    node.parent_id = _parent.id
    node.save
    nodes[i] << node
  end
end

