module Workers
  class Indexer
    include Sidekiq::Worker

    class IndexError < StandardError
    end

    class << self
      def defer(object_or_class)
        if object_or_class.is_a? Class
          params = { 'type' => object_or_class.document_type }
          perform_async(params)
        elsif object_or_class.id?
          params = {
            'id'   => object_or_class.id,
            'type' => object_or_class.class.document_type
          }
          perform_async(params)
        end
      rescue StandardError => e
        Rails.logger.debug "INDEXER: #{e.class} => #{e.message}"
        raise
      end
    end

    def perform(options)
      id, type = options.with_indifferent_access[:id], options.with_indifferent_access[:type]
      id.nil? ? update_class_index(type) : update_instance_index(type, id)
    end

    private

    def update_class_index(type)
      klass = RedmineElasticsearch.type2class(type)
      klass.update_index
    rescue Errno::ECONNREFUSED => e
      raise IndexError, e, e.backtrace
    end

    def update_instance_index(type, id)
      klass    = RedmineElasticsearch.type2class(type)
      document = klass.find id
      document.update_index
    rescue ActiveRecord::RecordNotFound
      begin
        klass.remove_from_index id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # do nothing
      end
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      # do nothing
    rescue Errno::ECONNREFUSED => e
      raise IndexError, e, e.backtrace
    end
  end
end
