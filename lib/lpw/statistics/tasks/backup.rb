require 'backup'
require 'elasticsearch/extensions/backup'

namespace :backup do
  desc "Parcing property from XML"
  task :start => :environment do
    # Add force ENV var. force will reload all
    indece = ENV['INDEX'] || ENV['index'] || 'lpw-statistics'
    Backup::Logger.configure do
      logfile.enabled = true
      logfile.log_path = '/tmp/backups/log'
    end; Backup::Logger.start!

    backup = Backup::Model.new(:elasticsearch, 'Backup Elasticsearch') do
      database Backup::Database::Elasticsearch do |db|
        db.url     = ENV['FOUNDELASTICSEARCH_URL']
        db.indices = indece
      end

      store_with Backup::Storage::S3 do |s3|
        # AWS Credentials
        s3.access_key_id     = ENV['AWS_ACCESS_KEY_ID']
        s3.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
        # Or, to use a IAM Profile:
        # s3.use_iam_profile = true

        s3.region             = ENV['AWS_REGION']
        s3.bucket             = ENV['ELASTIC_BACKUP_BUCKET']
        s3.path               = '/'
      end

    end

    backup.perform!

  end

end