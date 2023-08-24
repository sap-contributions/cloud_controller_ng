module VCAP::CloudController
  module Jobs
    module Runtime
      class ExpiredOrphanedBlobCleanup < VCAP::CloudController::Jobs::CCJob
        CUTOFF_AGE_IN_DAYS = 90

        def perform
          old_orphaned_blobs = OrphanedBlob.where(Sequel.lit("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", CUTOFF_AGE_IN_DAYS))
          logger = Steno.logger('cc.background.expired-orphaned-blob-cleanup')
          logger.info("Cleaning up #{old_orphaned_blobs.count} OrphanedBlob rows")
          old_orphaned_blobs.delete
        end

        def job_name_in_configuration
          :expired_orphaned_blob_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
