class AnimesController < ShikimoriController
  before_action :authenticate_user!, only: [:edit]
  before_action :fetch_resource, if: :resource_id
  before_action :set_breadcrumbs, if: -> { @resource }
  before_action :resource_redirect, if: -> { @resource }

  # временно отключаю, всё равно пока не тормозит
  #caches_action :page, :characters, :show, :related, :cosplay, :tooltip,
    #cache_path: proc {
      #id = params[:anime_id] || params[:manga_id] || params[:id]
      #@resource ||= klass.find(id.to_i)
      #"#{klass.name}|#{Digest::MD5.hexdigest params.to_json}|#{@resource.updated_at.to_i}|#{@resource.thread.updated_at.to_i}|#{json?}|v3|#{request.xhr?}"
    #},
    #unless: proc { user_signed_in? },
    #expires_in: 2.days

  # отображение аниме или манги
  def show
    @itemtype = @resource.itemtype
    page_title "#{@resource.russian_kind} #{@resource.name}", true
  end

  def characters
    redirect_to @resource.url if @resource.roles.main_characters.none? && @resource.roles.supporting_characters.none?
    page_title "Персонажи #{@resource.anime? ? 'аниме' : 'манги'}"
  end

  def staff
    redirect_to @resource.url if @resource.roles.people.none?
    page_title "Создатели #{@resource.anime? ? 'аниме' : 'манги'}"
  end

  def files
    redirect_to @resource.url unless user_signed_in?
    page_title 'Файлы'
  end

  def similar
    redirect_to @resource.url if @resource.related.similar.none?
    page_title(@resource.anime? ? 'Похожие аниме' : 'Похожая манга')
  end

  def screenshots
    page_title 'Кадры'
  end

  def videos
    page_title 'Видео'
  end

  def chronology
    page_title(@resource.anime? ? 'Хронология аниме' : 'Хронология манги')
  end

  #def recent
    #1/0
  #end

  def related
    page_title(@resource.anime? ? 'Связанное с аниме' : 'Связанное с мангой')
  end

  # TODO: удалить после 05.2015
  def comments
    redirect_to UrlGenerator.instance.topic_url(@resource.thread), status: 301
  end

  def reviews
    redirect_to @resource.url if @resource.comment_reviews_count.zero?
    page_title "Отзывы #{@resource.anime? ? 'об аниме' : 'о манге'}"
    #@canonical = UrlGenerator.instance.topic_url(@resource.thread)
  end

  def art
    page_title 'Арт с имиджборд'
  end

  def favoured
    redirect_to @resource.url if @resource.all_favoured.none?
    page_title 'В избранном'
  end

  def clubs
    redirect_to @resource.url if @resource.all_linked_clubs.none?
    page_title 'Клубы'
  end

  def resources
    render partial: 'resources'
  end

  def other_names
    noindex
  end

  # торренты к эпизодам аниме
  def episode_torrents
    render json: @resource.files.episodes_data
  end

  # редактирование аниме
  def edit
    noindex
    page_title 'Редактирование'
    @page = params[:page] || 'description'

    @user_change = UserChange.new(
      model: @resource.object.class.name,
      item_id: @resource.id,
      column: @page,
      source: @resource.source,
      value: @resource[@page],
      action: params[:page] == 'screenshots' ? UserChange::ScreenshotsPosition : nil
    )
  end

  ## подстраница косплея
  #def cosplay
    #1/0
    #show
    #render :show unless @director.redirected?
  #end

  # тултип
  def tooltip
  end

  # автодополнение
  def autocomplete
    @collection = AniMangaQuery.new(resource_klass, params, current_user).complete
  end

  # rss лента новых серий и сабов аниме
  #def rss
    #anime = Anime.find(params[:id].to_i)

    #case params[:type]
      #when 'torrents'
        #data = anime.torrents
        #title = "Торренты #{anime.name}"

      #when 'torrents_480p'
        #data = anime.torrents_480p
        #title = "Серии 480p #{anime.name}"

      #when 'torrents_720p'
        #data = anime.torrents_720p
        #title = "Серии 720p #{anime.name}"

      #when 'torrents_1080p'
        #data = anime.torrents_1080p
        #title = "Серии 1080p #{anime.name}"

      #when 'subtitles'
        #if anime.subtitles.include? params[:group]
          #data = anime.subtitles[params[:group]][:feed].reverse
        #else
          #data = []
        #end
        #title = "Субтитры #{anime.name}"
    #end

    #feed = RSS::Maker.make("2.0") do |feed|
      #feed.channel.title = title
      #feed.channel.link = request.url
      #feed.channel.description = "%s, найденные сайтом." % title
      #feed.items.do_sort = true # sort items by date

      #data.select {|v| v[:title] }.reverse.each do |item|
        #entry = feed.items.new_item

        #entry.title = item[:title].html_safe
        #entry.link = item[:link].html_safe
        #entry.description = "Seeders: %d, Leechers: %d" % [item[:seed], item[:leech]] if item[:seed] || item[:leech]
        #entry.date = item[:pubDate] != nil ? Time.at(item[:pubDate].to_i) : Time.now
      #end
    #end

    #response.headers['Content-Type'] = 'application/rss+xml; charset=utf-8'
    #render text: feed
  #end

private
  # класс текущего элемента
  #def klass
    #@klass ||= Object.const_get(self.class.name.underscore.split('_')[0].singularize.camelize)
  #end

  #def fetch_resource
    #@resource = klass.find(resource_id.to_i).decorate
  #end

  def set_breadcrumbs
    if @resource.anime?
      breadcrumb 'Список аниме', animes_url
      breadcrumb 'Сериалы', animes_url(type: @resource.kind) if @resource.kind == 'TV'
      breadcrumb 'Полнометражные', animes_url(type: @resource.kind) if @resource.kind == 'Movie'
    else
      breadcrumb 'Список манги', mangas_url
    end

    if @resource.aired_on && [Time.zone.now.year + 1, Time.zone.now.year, Time.zone.now.year - 1].include?(@resource.aired_on.year)
      breadcrumb "#{@resource.aired_on.year} год", send("#{@resource.object.class.name.downcase.pluralize}_url", season: @resource.aired_on.year)
    end

    if @resource.genres.any?
      breadcrumb UsersHelper.localized_name(@resource.main_genre, current_user), send("#{@resource.object.class.name.downcase.pluralize}_url", genre: @resource.main_genre.to_param)
    end

    # все страницы, кроме animes#show
    if @resource && (params[:action] != 'show' || params[:controller] == 'reviews')
      breadcrumb UsersHelper.localized_name(@resource, current_user), @resource.url
    end
  end
end
