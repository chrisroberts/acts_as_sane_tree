module ActsAsSaneTree
  
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
  end

  # Specify this +acts_as+ extension if you want to model a tree structure by providing a parent association and a children
  # association. This requires that you have a foreign key column, which by default is called +parent_id+.
  #
  #   class Category < ActiveRecord::Base
  #     acts_as_sane_tree :order => "name"
  #   end
  #
  #   Example:
  #   root
  #    \_ child1
  #         \_ subchild1
  #         \_ subchild2
  #
  #   root      = Category.create("name" => "root")
  #   child1    = root.children.create("name" => "child1")
  #   subchild1 = child1.children.create("name" => "subchild1")
  #
  #   root.parent   # => nil
  #   child1.parent # => root
  #   root.children # => [child1]
  #   root.children.first.children.first # => subchild1
  #
  # The following class methods are also added:
  # 
  # * <tt>nodes_within?(src, chk)</tt> - Returns true if chk contains any nodes found within src and all ancestors of nodes within src
  # * <tt>nodes_within(src, chk)</tt> - Returns any matching nodes from chk found within src and all ancestors within src
  # * <tt>nodes_and_descendents(*args)</tt> - Returns all nodes and descendents for given IDs or records. Accepts multiple IDs and records. Valid options:
  #   * :raw - No Hash nesting
  #   * :no_self - Will not return given nodes in result set
  #   * {:depth => n} - Will set maximum depth to query
  #   * {:to_depth => n} - Alias for :depth
  #   * {:at_depth => n} - Will return times at given depth (takes precedence over :depth/:to_depth)
  module ClassMethods
    # Configuration options are:
    #
    # * <tt>foreign_key</tt> - specifies the column name to use for tracking of the tree (default: +parent_id+)
    # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
    # * <tt>counter_cache</tt> - keeps a count in a +children_count+ column if set to +true+ (default: +false+).
    def acts_as_sane_tree(options = {})
      configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil, :max_depth => 10000 }
      configuration.update(options) if options.is_a?(Hash)

      belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]
      has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => :destroy
      
      validates_each configuration[:foreign_key] do |record, attr, value|
        record.errors.add attr, 'Cannot be own parent.' if !record.id.nil? && value.to_i == record.id.to_i
      end

      class_eval <<-EOV
        include ActsAsSaneTree::InstanceMethods

        def self.roots
          find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
        end

        def self.root
          find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
        end

        def self.nodes_within?(src, chk)
          s = (src.is_a?(Array) ? src : [src]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
          c = (chk.is_a?(Array) ? chk : [chk]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
          if(s.empty? || c.empty?)
            false
          else
            q = self.connection.select_all(
              "WITH RECURSIVE crumbs AS (
                SELECT #{self.table_name}.*, 0 AS level FROM #{self.table_name} WHERE id in (\#{s.join(', ')})
                UNION ALL
                SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{self.table_name} alias1 on alias1.parent_id = crumbs.id
              ) SELECT count(*) as count FROM crumbs WHERE id in (\#{c.join(', ')})"
            )
            q.first['count'].to_i > 0
          end
        end

        def self.nodes_within(src, chk)
          s = (src.is_a?(Array) ? src : [src]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
          c = (chk.is_a?(Array) ? chk : [chk]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
          if(s.empty? || c.empty?)
            nil
          else
            self.find_by_sql(
              "WITH RECURSIVE crumbs AS (
                SELECT #{self.table_name}.*, 0 AS level FROM #{self.table_name} WHERE id in (\#{s.join(', ')})
                UNION ALL
                SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{self.table_name} alias1 on alias1.parent_id = crumbs.id
                #{configuration[:max_depth] ? "WHERE crumbs.level + 1 < #{configuration[:max_depth].to_i}" : ''}
              ) SELECT * FROM crumbs WHERE id in (\#{c.join(', ')})"
            )
          end
        end
        
        def self.nodes_and_descendents(*args)
          raw = args.delete(:raw)
          no_self = args.delete(:no_self)
          at_depth = nil
          depth = nil
          hash = args.detect{|x|x.is_a?(Hash)}
          if(hash)
            args.delete(hash)
            depth = hash[:depth] || hash[:to_depth]
            at_depth = hash[:at_depth]
          end
          depth = #{configuration[:max_depth]} unless depth || at_depth
          depth_clause = at_depth ? "crumbs.level + 1 = \#{at_depth.to_i}" : "crumbs.level + 1 < \#{depth.to_i}"
          base_ids = args.map{|x| x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
          q = self.find_by_sql(
            "WITH RECURSIVE crumbs AS (
              SELECT #{self.table_name}.*, \#{no_self ? -1 : 0} AS level FROM #{self.table_name} WHERE \#{base_ids.empty? ? 'parent_id IS NULL' : "id in (\#{base_ids.join(', ')})"}
              UNION ALL
              SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{self.table_name} alias1 on alias1.parent_id = crumbs.id
              WHERE \#{depth_clause}
            ) SELECT * FROM crumbs WHERE level >= 0 ORDER BY level, parent_id ASC"
          )
          unless(raw)
            res = {}
            cache = {}
            q.each do |item|
              cache[item.id] = {}
              if(cache[item.parent_id])
                cache[item.parent_id][item] = cache[item.id]
              else
                res[item] = cache[item.id]
              end
            end
            res
          else
            q
          end
        end

      EOV
    end
  end

  module InstanceMethods
    
    # Returns all ancestors of the current node. 
    def ancestors
      self.class.find_by_sql "WITH RECURSIVE crumbs AS (
          SELECT #{self.class.table_name}.*,
          1 AS level
          FROM #{self.class.table_name}
          WHERE id = #{id} 
          UNION ALL
          SELECT alias1.*, 
          level + 1 
          FROM crumbs
          JOIN #{self.class.table_name} alias1 ON alias1.id = crumbs.parent_id
        ) SELECT * FROM crumbs WHERE id != #{id} ORDER BY level DESC"
    end

    # Returns the root node of the tree.
    def root
      ancestors.first
    end

    # Returns all siblings of the current node.
    #
    #   subchild1.siblings # => [subchild2]
    def siblings
      self_and_siblings - [self]
    end

    # Returns all siblings and a reference to the current node.
    #
    #   subchild1.self_and_siblings # => [subchild1, subchild2]
    def self_and_siblings
      parent ? parent.children : self.class.roots
    end
    
    # Returns if the current node is a root
    def root?
      parent_id.nil?
    end
    
    # Returns all descendents of the current node. Each level
    # is within its own hash, so for a structure like:
    #   root
    #    \_ child1
    #         \_ subchild1
    #               \_ subsubchild1
    #         \_ subchild2
    # the resulting hash would look like:
    # 
    #  {child1 => 
    #    {subchild1 => 
    #      {subsubchild1 => {}},
    #     subchild2 => {}}}
    #
    # This method will accept two parameters.
    #   * :raw -> Result is flat array. No Hash tree is built
    #   * {:depth => n} -> Will only search for descendents to the given depth of n
    def descendents(*args)
      args.delete_if{|x| !x.is_a?(Hash) && x != :raw}
      self.class.nodes_and_descendents(:no_self, self, *args)
    end
    
    # Returns the depth of the current node. 0 depth represents the root of the tree
    def depth
      res = self.class.connection.select_all(
        "WITH RECURSIVE crumbs AS (
          SELECT parent_id, 0 AS level
          FROM #{self.class.table_name}
          WHERE id = #{id} 
          UNION ALL
          SELECT alias1.parent_id, level + 1 
          FROM crumbs
          JOIN #{self.class.table_name} alias1 ON alias1.id = crumbs.parent_id
        ) SELECT level FROM crumbs ORDER BY level DESC LIMIT 1"
      )
      res.empty? ? nil : res.first['level']
    end
  end
end

ActiveRecord::Base.send :include, ActsAsSaneTree