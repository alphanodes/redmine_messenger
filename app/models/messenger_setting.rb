# frozen_string_literal: true

class MessengerSetting < (defined?(ApplicationRecord) == 'constant' ? ApplicationRecord : ActiveRecord::Base)
  belongs_to :project

  validates :messenger_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  def self.find_or_create(project_id)
    setting = MessengerSetting.find_by project_id: project_id
    unless setting
      setting = MessengerSetting.new
      setting.project_id = project_id
      setting.save!
    end

    setting
  end

  def filter_issue_statuses=(value)
    super(value.reject(&:empty?).join(','))
  end

  def filter_issue_statuses
    return self[:filter_issue_statuses].split(',').map(&:to_i) if self[:filter_issue_statuses]

    self[:filter_issue_statuses]
  end

  def filter_issue_trackers=(value)
    super(value.reject(&:empty?).join(','))
  end

  def filter_issue_trackers
    return self[:filter_issue_trackers].split(',').map(&:to_i) if self[:filter_issue_trackers]

    self[:filter_issue_trackers]
  end
end
