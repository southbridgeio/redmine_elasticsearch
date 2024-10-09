require 'redmine'

register_after_redmine_initialize_proc =
  if Redmine::VERSION::MAJOR >= 5
    Rails.application.config.public_method(:after_initialize)
  else
    reloader = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Reloader
    reloader.public_method(:to_prepare)
  end
register_after_redmine_initialize_proc.call do
  paths = '/lib/redmine_elasticsearch/{patches/*_patch}.rb'

  Dir.glob(File.dirname(__FILE__) + paths).each do |file|
    require_dependency file
  end

  RedmineElasticsearch.apply_patch RedmineElasticsearch::Patches::RedmineSearchPatch, Redmine::Search
  RedmineElasticsearch.apply_patch RedmineElasticsearch::Patches::SearchControllerPatch, SearchController
  RedmineElasticsearch.apply_patch RedmineElasticsearch::Patches::ResponseResultsPatch, Elasticsearch::Model::Response::Results
  # Using plugin's configured client in all models
  Elasticsearch::Model.client = RedmineElasticsearch.client
end

paths = Dir.glob("#{Rails.application.config.root}/plugins/redmine_elasticsearch/{lib,app/models,app/controllers}")

Rails.application.config.eager_load_paths += paths
Rails.application.config.autoload_paths += paths
ActiveSupport::Dependencies.autoload_paths += paths

Redmine::Plugin.register :redmine_elasticsearch do
  name        'Redmine Elasticsearch Plugin'
  description 'This plugin integrates the Elasticsearch full-text search engine into Redmine.'
  author      'Restream'
  version     '0.2.1'
  url         'https://github.com/Restream/redmine_elasticsearch'

  requires_redmine version_or_higher: '2.1'
end

require './plugins/redmine_elasticsearch/lib/redmine_elasticsearch'
