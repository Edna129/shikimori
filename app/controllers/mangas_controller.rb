class MangasController < AnimesController
  def autocomplete
    @collection = Autocomplete::Manga.call(
      scope: Manga.where.not(kind: Ranobe::KIND),
      phrase: params[:search] || params[:q]
    )
  end

private

  def resource_redirect
    if @resource.ranobe?
      redirect_url =
        url_for(url_params.merge(action: params[:action], controller: 'ranobe'))
      return redirect_to redirect_url, status: 301
    end

    super
  end

  def update_params
    params
      .require(:manga)
      .permit(
        :russian,
        :tags,
        :description_ru,
        :description_en,
        *Manga::DESYNCABLE
      )
  end
end
