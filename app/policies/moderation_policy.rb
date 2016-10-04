class ModerationPolicy
  prepend ActiveCacher.instance

  pattr_initialize :user, :moderation_filter
  instance_cache :reviews_count, :abuse_abuses_count,
    :abuse_pending_count, :other_versions_count, :video_versions_count

  def reviews_count
    return 0 unless !@moderation_filter || @user&.reviews_moderator?
    Review.pending.size
  end

  def abuses_count
    return 0 unless !@moderation_filter || @user&.moderator?
    AbuseRequest.abuses.size + AbuseRequest.pending.size
  end

  def content_count
    return 0 unless !@moderation_filter || @user&.versions_moderator?
    Version.pending_content.size
  end

  def videos_count
    return 0 unless !@moderation_filter || @user&.video_moderator?
    Version.pending_videos.size
  end

  def video_reports_count
    return 0 unless @user&.video_moderator?
    AnimeVideoReport.pending.size
  end
end
