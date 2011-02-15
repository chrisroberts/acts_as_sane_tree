module ActsAsSaneTree
  module InstanceMethods
    
    # Returns all ancestors of the current node. 
    def ancestors
      self.find_by_sql "WITH RECURSIVE crumbs AS (
          SELECT #{self.table_name}.*,
          1 AS level
          FROM #{self.table_name}
          WHERE id = #{id} 
          UNION ALL
          SELECT alias1.*, 
          level + 1 
          FROM crumbs
          JOIN #{self.table_name} alias1 ON alias1.id = crumbs.parent_id
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
      res = self.connection.select_all(
        "WITH RECURSIVE crumbs AS (
          SELECT parent_id, 0 AS level
          FROM #{self.table_name}
          WHERE id = #{id} 
          UNION ALL
          SELECT alias1.parent_id, level + 1 
          FROM crumbs
          JOIN #{self.table_name} alias1 ON alias1.id = crumbs.parent_id
        ) SELECT level FROM crumbs ORDER BY level DESC LIMIT 1"
      )
      res.empty? ? nil : res.first['level']
    end
  end
end
