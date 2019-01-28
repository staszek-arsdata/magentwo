module Magentwo
  class Dataset
    DefaultPageSize = 20

    attr_accessor :model, :opts
    def initialize model, opts=nil
      self.model = model
      self.opts = opts || {
        :filters => [],
        :pagination => {
          :current_page => Filter::CurrentPage.new(1),
          :page_size => Filter::PageSize.new(DefaultPageSize)
        },
        :ordering => [],
        :fields => nil
      }
    end

    #################
    # Filters
    ################
    def filter hash_or_other, invert:false
      filter = case hash_or_other
      when Hash
        raise ArgumentError, "empty hash supplied" if hash_or_other.empty?
        key, value = hash_or_other.first
        klass = case value
        when Array
          invert ? Filter::Nin : Filter::In
        else
          invert ? Filter::Neq : Filter::Eq
        end
        klass.new(key, value)
      else
        raise ArgumentError, "filter function expects Hash as input"
      end
      Dataset.new self.model, self.opts.merge(:filters => self.opts[:filters] + [filter])
    end

    def exclude args
      filter args, invert:true
    end

    def select *fields
      Dataset.new self.model, self.opts.merge(:fields => Filter::Fields.new(fields))
    end

    def like args
      Dataset.new self.model, self.opts.merge(:filters => self.opts[:filters] + [Filter::Like.new(args.keys.first, args.values.first)])
    end

    #################
    # Pagination
    ################
    def page page, page_size=DefaultPageSize
      Dataset.new self.model, self.opts.merge(:pagination => {:current_page => Filter::CurrentPage.new(page), :page_size => Filter::PageSize.new(page_size)})
    end

    #################
    # Ordering
    ################
    def order_by field, direction="ASC"
      Dataset.new self.model, self.opts.merge(:ordering => self.opts[:ordering] + [Filter::OrderBy.new(field, direction)])
    end

    #################
    # Fetching
    ################
    def info
      result = self.model.get self.page(1, 1).to_query, {:meta_data => true}
      {
        :fields => result[:items]&.first&.keys,
        :total_count => result[:total_count]
      }
    end

    def count
      self.info[:total_count]
    end

    def fields
      self.info[:fields]
    end

    def first
      self.model.first
    end

    def all
      self.model.all
    end

    #################
    # Transformation
    ################
    def to_query
      [
        self.opts[:filters]
        .each_with_index
        .map { |opt, idx| opt.to_query(idx) }
        .join("&"),

        self.opts[:pagination]
        .map { |k, v| v.to_query}
        .join("&"),


        self.opts[:ordering]
        .map { |opt, idx| opt.to_query(idx) }
        .join("&"),

        self.opts[:fields]? self.opts[:fields].to_query() : ""
      ].reject(&:empty?)
      .join("&")
    end

    #################
    # Functors
    ################
    def map(&block)
      raise ArgumentError, "no block given" unless block_given?
      self.model.all.map(&block)
    end

    def each(&block)
      raise ArgumentError, "no block given" unless block_given?
      self.model.all.each(&block)
    end
  end
end
