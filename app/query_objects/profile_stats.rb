class ProfileStats
  prepend ActiveCacher.instance
  include Translation

  instance_cache :graph_statuses, :anime_spent_time, :manga_spent_time, :spent_time
  instance_cache :comments_count, :comments_reviews_count, :reviews_count, :user_changes_count, :uploaded_videos_count

  def initialize user, current_user
    @user = user
    @current_user = current_user

    @stats = Rails.cache.fetch [:stats, :v7, @user] do
      UserStatisticsQuery.new @user
    end
  end

  def graph_statuses
    @stats.by_statuses
  end

  #def graph_time
    #GrapthTime.new spent_time
  #end

  def anime_spent_time
    time = @stats.anime_rates.sum {|v| SpentTimeDuration.new(v).anime_hours v.entry_episodes, v.duration }
    SpentTime.new time / 60.0 / 24
  end

  def manga_spent_time
    time = @stats.manga_rates.sum {|v| SpentTimeDuration.new(v).manga_hours v.entry_chapters, v.entry_volumes }
    SpentTime.new time / 60.0 / 24
  end

  def spent_time
    SpentTime.new anime_spent_time.days + manga_spent_time.days
  end

  def spent_time_percent
    part = 20

    #if spent_time.hours > 0 && spent_time.hours <= 1
      #spent_time.hours * part / 2

    if spent_time.weeks > 0 && spent_time.weeks <= 1
      spent_time.weeks * part / 2

    elsif spent_time.months > 0 && spent_time.months <= 1
      10 + (spent_time.days - 7) / 23 * part

    elsif spent_time.months_3 > 0 && spent_time.months_3 <= 1
      30 + (spent_time.days - 30) / 60 * part

    elsif spent_time.months_6 > 0 && spent_time.months_6 <= 1
      50 + (spent_time.days - 90) / 90 * part

    elsif spent_time.years > 0 && spent_time.years <= 1
      70 + (spent_time.days - 180) / 185 * part

    elsif spent_time.years > 1 && spent_time.years <= 1.5
      90 + (spent_time.days - 365) / 182.5 * (part / 2)

    elsif spent_time.years > 1.5
      100

    else
      0
    end.round
  end

  def spent_time_in_words
    I18n.spent_time spent_time, false
  end

  def spent_time_in_days
    anime_days = anime_spent_time.days > 10 ? anime_spent_time.days.to_i : anime_spent_time.days.round(1)
    manga_days = manga_spent_time.days > 10 ? manga_spent_time.days.to_i : manga_spent_time.days.round(1)
    total_days = spent_time.days > 10 ? spent_time.days.to_i : spent_time.days.round(1)

    days_text = "Всего #{total_days.zero? ? 0 : total_days} " +
      Russian.p(total_days, 'день', 'дня', 'дней', 'дней')

    if anime_spent_time.days >= 0.5 && manga_spent_time.days >= 0.5
      "#{days_text}: " +
        "#{anime_days} #{Russian.p(anime_days, 'день', 'дня', 'дней', 'дней')} аниме" +
        " и #{manga_days} #{Russian.p(manga_days, 'день', 'дня', 'дней', 'дней')} манга"

    elsif anime_spent_time.days >= 1
      "#{days_text} аниме"

    elsif manga_spent_time.days >= 1
      "#{days_text} манга"

    else
      days_text
    end
  end

  def spent_time_label
    i18n_key = if anime? && manga?
      'anime_manga'
    elsif manga?
      'manga'
    else
      'anime'
    end

    i18n_t "time_spent.#{i18n_key}"
  end

  def time_since_signup
    time = SpentTime.new((Time.zone.now - User.first.created_at) / 1.day)
    localize_spent_time time, false
  end

  def activity size
    @stats.by_activity size
  end

  def list_counts list_type
    if list_type.to_sym == :anime
      @stats.statuses @stats.anime_rates, true
    else
      @stats.statuses @stats.manga_rates, true
    end
  end

  def scores list_type
    @stats.by_criteria(:score, 1.upto(10).to_a.reverse)[list_type.to_sym]
  end

  def types list_type
    @stats.by_criteria(
      :kind,
      list_type.to_s.capitalize.constantize.kind.values,
      "enumerize.#{list_type}.kind.short.%s"
    )[list_type.to_sym]
  end

  def ratings list_type
    @stats.by_criteria(
      :rating,
      list_type.to_s.capitalize.constantize.rating.values.select { |v| v != 'none' },
      "enumerize.#{list_type}.rating.%s"
    )[list_type.to_sym]
  end

  def genres
    {
      anime: @stats.by_categories('genre', @stats.genres, @stats.anime_valuable_rates, [], 19),
      manga: @stats.by_categories('genre', @stats.genres, [], @stats.manga_valuable_rates, 19)
    }
  end

  def studios
    { anime: @stats.by_categories('studio', @stats.studios.select {|v| v.real? }, @stats.anime_valuable_rates, nil, 17) }
  end

  def publishers
    { manga: @stats.by_categories('publisher', @stats.publishers, nil, @stats.manga_valuable_rates, 17) }
  end

  def statuses
    { anime: @stats.anime_statuses(false), manga: @stats.manga_statuses(false) }
  end

  def full_statuses
    { anime: @stats.anime_statuses(true), manga: @stats.manga_statuses(true) }
  end

  def manga_statuses
  end

  def social_activity?
    comments_count > 0 || comments_reviews_count > 0 || reviews_count > 0 ||
      content_changes_count > 0 || videos_changes_count > 0
  end

  def comments_count
    Comment.where(user_id: @user.id).count
  end

  def comments_reviews_count
    Comment.where(user_id: @user.id, review: true).count
  end

  def reviews_count
    @user.reviews.count
  end

  def content_changes_count
    @user.user_changes.where(status: [UserChangeStatus::Taken, UserChangeStatus::Accepted]).count
  end

  def videos_changes_count
    AnimeVideoReport.where(user: @user).where.not(state: 'rejected').count
  end

  def anime?
    @stats.anime_rates.any?
  end

  def manga?
    @stats.manga_rates.any?
  end
end
