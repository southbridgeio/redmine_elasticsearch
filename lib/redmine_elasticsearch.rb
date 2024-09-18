require 'elasticsearch'
require 'elasticsearch/model'

module RedmineElasticsearch
  INDEX_NAME            = "#{Rails.application.class.module_parent_name.downcase}_#{Rails.env}"
  BATCH_SIZE_FOR_IMPORT = 300

  def type2class_name(type)
    type.to_s.underscore.classify
  end

  def type2class(type)
    self.type2class_name(type).constantize
  end

  def search_klasses
    Redmine::Search.available_search_types.map { |type| type2class(type) }
  end

  def apply_patch(patch, *targets)
    targets = Array(targets).flatten
    targets.each do |target|
      unless target.included_modules.include? patch
        target.send :prepend, patch
      end
    end
  end

  def additional_index_properties(document_type)
    @additional_index_properties                = {}
    @additional_index_properties[document_type] ||= begin
      Rails.configuration.respond_to?(:additional_index_properties) ?
        Rails.configuration.additional_index_properties.fetch(document_type, {}) : {}
    end
  end

  def client(cache: true)
    if cache
      @client ||= Elasticsearch::Client.new client_options
    else
      @client = Elasticsearch::Client.new client_options
    end
  end

  def client_options
    @client_options ||=
      (Redmine::Configuration['elasticsearch'] || { request_timeout: 180 }).symbolize_keys
  end

  # Refresh the index and to make the changes (creates, updates, deletes) searchable.
  def refresh_indices
    client.indices.refresh
  end

  extend self
end
