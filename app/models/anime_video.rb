# TODO : проверить необходимость метода allowed?
# TODO : вынести методы относящиеся ко вью в декоратор.
class AnimeVideo < ApplicationRecord
  # для Versions
  SIGNIFICANT_FIELDS = []

  belongs_to :anime
  belongs_to :author,
    class_name: AnimeVideoAuthor.name,
    foreign_key: :anime_video_author_id
  has_many :reports, class_name: AnimeVideoReport.name, dependent: :destroy

  enumerize :kind,
    in: %i[fandub unknown subtitles raw],
    default: :unknown,
    predicates: true
  enumerize :language,
    in: %i[russian unknown original english],
    default: :unknown,
    predicates: { prefix: true }
  enumerize :quality,
    in: %i[bd dvd web tv unknown],
    default: :unknown,
    predicates: { prefix: true }

  validates :anime, :source, :kind, presence: true
  validates :url,
    presence: true,
    anime_video_url: true,
    if: -> { new_record? || changes['url'] }
  validates :episode, numericality: { greater_than_or_equal_to: 0 }

  before_save :check_copyrighted_authors,
    if: :anime_video_author_id_changed?
  before_save :check_banned_hostings
  before_save :check_copyrighted_animes
  after_create :create_episode_notificaiton, unless: :any_videos?

  R_OVA_EPISODES = 2
  ADULT_OVA_CONDITION = <<-SQL.squish
    (
      animes.rating = '#{Anime::SUB_ADULT_RATING}' and
      (
        (animes.kind = 'ova' and animes.episodes <= #{R_OVA_EPISODES}) or
        animes.kind = 'Special'
      )
    )
  SQL
  PLAY_CONDITION = <<-SQL.squish
    animes.rating != '#{Anime::ADULT_RATING}' and
    animes.censored = false and
    not #{ADULT_OVA_CONDITION}
  SQL
  XPLAY_CONDITION = <<-SQL.squish
    animes.rating = '#{Anime::ADULT_RATING}' or
    animes.censored = true or
    #{ADULT_OVA_CONDITION}
  SQL

  scope :allowed_play, -> { available.joins(:anime).where(PLAY_CONDITION) }
  scope :allowed_xplay, -> { available.joins(:anime).where(XPLAY_CONDITION) }

  scope :available, -> { where state: %w[working uploaded] }

  COPYRIGHT_BAN_ANIME_IDS = [
    36144, # Garo: Vanishing Line - Wakanim (Russia + Eastern Europe) 2017-10-01 - 2024-10-01
    35078, # Mitsuboshi Colors - Wakanim (Russia + Europe except Italy&Spanish) 2018-08-01 - 2022-07-01
    33354, # Cardcaptor Sakura: Clear Card-hen - Wakanim (Russia + French) 2018-01-01 - 2022-01-01
    35320, # Cardcaptor Sakura: Clear Card-hen Prologue - Sakura and two Bears - Wakanim (Russia + French) 2018-01-01 - 2022-01-01
    35073, # Overlord II - Wakanim (Russia) 2018-01-01 - 2022-01-01
    33478, # UQ Holder!: Mahou Sensei Negima! 2 - Wakanim (Russia) 2017-10-01 - 2024-10-01
    36027, # King's Game - Wakanim (Russia + French) 2017-10-01 - 2024-10-01
    35838, # Girls' Last Tour - Wakanim (Russia + French) 2017-10-01 - 2020-10-01
    35712, # My Girlfriend is too much to handle - Wakanim (Russia + French) 2017-10-01 - 2020-10-01
    36094, # Hakumei to Mikochi - Wakanim (Russia + French) 2018-01-01 - 2022-01-01
    1546, # Negima?! - Wakanim (Russia + French) 2018-01-01 - 2022-01-01
    157, # Mahou Sensei Negima! - Wakanim (Russia + French) 2018-01-01 - 2022-01-01
  ]

  state_machine :state, initial: :working do
    state :working
    state :uploaded
    state :rejected
    state :broken
    state :wrong
    state :banned
    state :copyrighted

    event :broken do
      transition %i[working uploaded broken rejected] => :broken
    end
    event :wrong do
      transition %i[working uploaded wrong rejected] => :wrong
    end
    event :ban do
      transition working: :banned
    end
    event :reject do
      transition %i[uploaded wrong broken banned] => :rejected
    end
    event :work do
      transition %i[uploaded broken wrong banned] => :working
    end
    event :uploaded do
      transition %i[working uploaded] => :working
    end

    after_transition(
      %i[working uploaded] => %i[broken wrong banned],
      unless: :any_videos?,
      do: :rollback_episode_notification
    )
    after_transition(
      %i[working uploaded] => %i[broken wrong banned],
      do: :process_reports
    )
  end

  def url= value
    video_url = Url.new(value).with_http.to_s if value.present?
    if video_url.present?
      extracted_url = VideoExtractor::UrlExtractor.call video_url
    end

    if extracted_url.present?
      super Url.new(extracted_url).with_http.to_s
    else
      super extracted_url
    end
  end

  def hosting
    AnimeOnline::ExtractHosting.call url
  end

  def vk?
    hosting == 'vk.com'
  end

  def smotret_anime?
    hosting == 'smotret-anime.ru'
  end

  def allowed?
    working? || uploaded?
  end

  def copyright_ban?
    COPYRIGHT_BAN_ANIME_IDS.include? anime_id
  end

  def uploader
    @uploader ||= AnimeVideoReport.find_by(
      anime_video_id: id,
      kind: 'uploaded'
    )&.user
  end

  def author_name
    author.try :name
  end

  def author_name= name
    self.author = AnimeVideoAuthor.find_or_create_by name: name&.strip
  end

  def any_videos?
    SameVideos.call(self).any?
  end

private

  def check_copyrighted_authors
    return unless author_name&.match? /wakanim|crunchyroll/i
    errors.add :base, 'Видео этого автора не могут быть загружены на сайт'
    throw :abort
  end

  def check_banned_hostings
    if hosting == 'kiwi.kz' || hosting == 'dailymotion.com'
      self.state = 'banned'
    end
  end

  def check_copyrighted_animes
    self.state = 'copyrighted' if copyright_ban?
  end

  def create_episode_notificaiton
    EpisodeNotification::Create.call(
      anime_id: anime_id,
      episode: episode,
      kind: kind
    )
  end

  def rollback_episode_notification
    EpisodeNotification::Rollback.call(
      anime_id: anime_id,
      episode: episode,
      kind: kind
    )
  end

  def process_reports
    reports.each do |report|
      process_report report
    end
  end

  def process_report report
    if (report.wrong? || report.broken? || report.other?) && report.pending?
      report.accept_only! BotsService.get_poster
    elsif report.uploaded? && report.can_post_reject?
      report.post_reject!
    end
  end
end
