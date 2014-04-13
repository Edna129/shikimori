class AnimeDecorator < AniMangaDecorator
  # скриншоты
  def screenshots limit=nil
    (@screenshots ||= {})[limit] ||= if object.respond_to? :screenshots
      object.screenshots.limit limit
    else
      []
    end
  end

  # видео
  def videos limit=nil
    (@videos ||= {})[limit] ||= if object.respond_to? :videos
      object.videos.limit limit
    else
      []
    end
  end

  # презентер файлов
  def files
    @files ||= AniMangaPresenter::FilesPresenter.new object, h
  end

  # ролики, отображаемые на инфо странице аниме
  def main_videos
    @main_videos ||= object.videos.limit(2)
  end

  def next_episode_at
    if object.episodes_aired && (object.ongoing? || object.anons?)
      calendars = object.anime_calendars.where(episode: [object.episodes_aired + 1, object.episodes_aired + 2])
      if calendars[0].present? && calendars[0].start_at > Time.zone.now
        @next_episode_at = calendars[0].start_at
      elsif calendars[1].present?
        @next_episode_at = calendars[1].start_at
      end
    end
  end

end
