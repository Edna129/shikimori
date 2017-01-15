REQUIRED_TEXT = [
  'MyAnimeList.net</title>',
  '</html>'
]
BAD_ID_ERRORS = [
  'Invalid ID provided',
  'No manga found, check the manga id and try again',
  'No series found, check the series id and try again'
]
BAN_TEXTS = [
  'Access has been restricted for this account'
]

MalParser.configuration.http_get = lambda do |url|
  Rails.cache.fetch([url, :v2], expires_in: 1.day) do
    content = Proxy.get(
      url,
      timeout: 30,
      required_text: REQUIRED_TEXT,
      ban_texts: BAN_TEXTS,
      no_proxy: Rails.env.test?,
      log: !Rails.env.test?
    )

    raise EmptyContentError, url unless content
    raise InvalidIdError, url if BAD_ID_ERRORS.any? { |v| content.include? v }

    content
  end
end
