json.content render(@collection, with_headline: true, with_headline: true)

if @add_postloader
  json.postloader render('blocks/postloader', filter: 'b-cosplay_gallery', url: cosplay_character_url(@resource, @page+1))
end
