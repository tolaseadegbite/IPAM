class VersionsPruneJob < ApplicationJob
  queue_as :maintenance

  # Deletes audit versions (and append-only card activities, which share
  # the retention window) older than the retention window in batches
  # to avoid long table locks. Safe to re-run; only touches old rows.
  def perform(retention: 12.months)
    PaperTrail::Version.where("created_at < ?", retention.ago).in_batches.delete_all
    CardActivity.where("created_at < ?", retention.ago).in_batches.delete_all
  end
end
