module ActsAsSaneTree
  module SingletonMethods

    def roots
      find(:all, :conditions => "#{@configuration[:foreign_key]} IS NULL", :order => @configuration[:order])
    end

    def root
      find(:first, :conditions => "#{@configuration[:foreign_key]} IS NULL", :order => @configuration[:order])
    end

    def nodes_within?(src, chk)
      s = (src.is_a?(Array) ? src : [src]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
      c = (chk.is_a?(Array) ? chk : [chk]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
      if(s.empty? || c.empty?)
        false
      else
        q = self.connection.select_all(
          "WITH RECURSIVE crumbs AS (
            SELECT #{table_name}.*, 0 AS level FROM #{table_name} WHERE id in (#{s.join(', ')})
            UNION ALL
            SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{table_name} alias1 on alias1.parent_id = crumbs.id
          ) SELECT count(*) as count FROM crumbs WHERE id in (#{c.join(', ')})"
        )
        q.first['count'].to_i > 0
      end
    end

    def nodes_within(src, chk)
      s = (src.is_a?(Array) ? src : [src]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
      c = (chk.is_a?(Array) ? chk : [chk]).map{|x|x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
      if(s.empty? || c.empty?)
        nil
      else
        self.find_by_sql(
          "WITH RECURSIVE crumbs AS (
            SELECT #{table_name}.*, 0 AS level FROM #{table_name} WHERE id in (\#{s.join(', ')})
            UNION ALL
            SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{table_name} alias1 on alias1.parent_id = crumbs.id
            #{@configuration[:max_depth] ? "WHERE crumbs.level + 1 < #{@configuration[:max_depth].to_i}" : ''}
          ) SELECT * FROM crumbs WHERE id in (#{c.join(', ')})"
        )
      end
    end
    
    def nodes_and_descendents(*args)
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
      depth ||= #{@configuration[:max_depth].to_i}
      depth_restriction = "WHERE crumbs.level + 1 < #{depth}" if depth
      depth_clause = nil
      if(at_depth)
        depth_clause = "level + 1 = #{at_depth.to_i}"
      elsif(depth)
        depth_clause = "level + 1 < #{depth.to_i}"
      end
      base_ids = args.map{|x| x.is_a?(ActiveRecord::Base) ? x.id : x.to_i}
      q = self.find_by_sql(
        "WITH RECURSIVE crumbs AS (
          SELECT #{table_name}.*, #{no_self ? -1 : 0} AS level FROM #{table_name} WHERE #{base_ids.empty? ? 'parent_id IS NULL' : "id in (#{base_ids.join(', ')})"}
          UNION ALL
          SELECT alias1.*, crumbs.level + 1 FROM crumbs JOIN #{table_name} alias1 on alias1.parent_id = crumbs.id
          #{depth_restriction}
        ) SELECT * FROM crumbs WHERE level >= 0 #{"AND " + depth_clause if depth_clause} ORDER BY level, parent_id ASC"
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

  end
end
