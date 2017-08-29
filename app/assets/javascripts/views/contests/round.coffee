using 'Contests'
module.exports = class Contests.Round extends View
  initialize: (votes) ->
    @votes = votes || {}

    @$match_container = @$ '.match-container'

    @_set_votes @votes
    @_switch_match @_initial_match_id()

    @$('.match-day .match-link').on 'click', (e) =>
      @_switch_match $(e.currentTarget).data('id')

  _set_votes: (votes) ->
    Object.forEach votes, (vote) =>
      @_set_vote vote.match_id, vote.vote if vote.vote

  _set_vote: (match_id, vote) ->
    @_$match_line(match_id).addClass("voted-#{vote}")

  _$match_line: (match_id) ->
    $(".match-day .match-link[data-id=#{match_id}]")

  _initial_match_id: ->
    @$root.data('match_id') ||
      @$('.match-day .match-link.started').first().data('id') ||
      @$('.match-day .match-link').first().data('id')

  _switch_match: (match_id) ->
    $match = @_$match_line match_id
    @$match_container.addClass 'b-ajax'

    axios
      .get($match.data('match_url'))
      .then (response) =>
        @$('.match-link.active').removeClass 'active'
        $match.addClass('active')

        @_match_loaded match_id, response.data

        page_url = $match.data('page_url')
        if Modernizr.history && page_url
          window.history.replaceState(
            { turbolinks: true, url: page_url },
            '',
            page_url
          )

  _match_loaded: (match_id, html) ->
    $match = $(html).process()
    @$('.match-container').removeClass('b-ajax').html($match)

    new Contests.Match($match, @votes[match_id], @)

    $first_member = @$('.match-members .match-member').first()
    $.scrollTo $first_member unless $first_member.is(':appeared')
