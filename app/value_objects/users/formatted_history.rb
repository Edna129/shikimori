class Users::FormattedHistory
  include ShallowAttributes
  include Draper::ViewHelpers

  attribute :name, String
  attribute :russian, String
  attribute :image, String
  attribute :image_2x, String
  attribute :action, String
  attribute :created_at, ActiveSupport::TimeWithZone
  attribute :url, String
  attribute :action_info, String

  def localized_name
    h.localization_span self
  end

  def reversed_action
    action
      .split(/(?<!\d[йяюо]), (?!\d)/)
      .reverse
      .join(', ')
      .gsub(/<.*?>/, '')
  end

  def special?
    action_info.present?
  end

  def localized_date
    h.l(created_at, format: '%e %B %Y').strip
  end
end
