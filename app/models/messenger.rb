require 'net/http'
require 'uri'

class Messenger
  include Redmine::I18n

  class << self
    def markup_format(text)
      # TODO: output format should be markdown, but at the moment there is no
      #       solution without using pandoc (http://pandoc.org/), which requires
      #       packages on os level
      #
      # Redmine::WikiFormatting.html_parser.to_text(text)

      text = text.to_s.dup

      # @see https://api.slack.com/reference/surfaces/formatting#escaping

      text.gsub!('&', '&amp;')
      text.gsub!('<', '&lt;')
      text.gsub!('>', '&gt;')

      text
    end

    def default_url_options
      { only_path: true, script_name: Redmine::Utils.relative_url_root }
    end

    def speak(msg, channels, url, options)
      url ||= RedmineMessenger.settings[:messenger_url]
      return if url.blank? || channels.blank?

      params = { text: msg, link_names: 1 }
      username = textfield_for_project(options[:project], :messenger_username)
      params[:username] = username if username.present?
      params[:attachments] = options[:attachment]&.any? ? [options[:attachment]] : []
      icon = textfield_for_project options[:project], :messenger_icon
      if icon.present?
        if icon.start_with? ':'
          params[:icon_emoji] = icon
        else
          params[:icon_url] = icon
        end
      end

      channels.each do |channel|
        uri = URI(url)
        params[:channel] = channel
        http_options = { use_ssl: uri.scheme == 'https' }
        http_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE unless RedmineMessenger.setting?(:messenger_verify_ssl)
        begin
          req = Net::HTTP::Post.new uri
          req.set_form_data payload: params.to_json
          Net::HTTP.start(uri.hostname, uri.port, http_options) do |http|
            response = http.request req
            Rails.logger.warn(response.inspect) unless [Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK].include? response
          end
        rescue StandardError => e
          Rails.logger.warn "cannot connect to #{url}"
          Rails.logger.warn e
        end
      end
    end

    def object_url(obj)
      if Setting.host_name.to_s =~ %r{\A(https?://)?(.+?)(:(\d+))?(/.+)?\z}i
        host = Regexp.last_match 2
        port = Regexp.last_match 4
        prefix = Regexp.last_match 5
        Rails.application.routes.url_for(obj.event_url(host: host, protocol: Setting.protocol, port: port, script_name: prefix))
      else
        Rails.application.routes.url_for(obj.event_url(host: Setting.host_name, protocol: Setting.protocol, script_name: ''))
      end
    end

    def url_for_project(proj)
      return if proj.blank?

      # project based
      pm = MessengerSetting.find_by project_id: proj.id
      return pm.messenger_url if !pm.nil? && pm.messenger_url.present?

      # parent project based
      parent_url = url_for_project proj.parent
      return parent_url if parent_url.present?
      # system based
      return RedmineMessenger.settings[:messenger_url] if RedmineMessenger.settings[:messenger_url].present?

      nil
    end

    def project_url_markdown(project)
      "[#{project.name}](#{object_url project})"
    end

    def url_markdown(obj, name)
      "[#{name}](#{object_url obj})"
    end

    def textfield_for_project(proj, config)
      return if proj.blank?

      # project based
      pm = MessengerSetting.find_by project_id: proj.id
      return pm.send(config) if !pm.nil? && pm.send(config).present?

      default_textfield proj, config
    end

    def default_textfield(proj, config)
      # parent project based
      parent_field = textfield_for_project proj.parent, config
      return parent_field if parent_field.present?
      return RedmineMessenger.settings[config] if RedmineMessenger.settings[config].present?

      ''
    end

    def channels_for_project(proj)
      return [] if proj.blank?

      # project based
      pm = MessengerSetting.find_by(project_id: proj.id)
      if !pm.nil? && pm.messenger_channel.present?
        return [] if pm.messenger_channel == '-'

        return pm.messenger_channel.split(',').map!(&:strip).uniq
      end
      default_project_channels proj
    end

    def setting_for_project(proj, config)
      return false if proj.blank?

      @setting_found = 0
      # project based
      pm = MessengerSetting.find_by(project_id: proj.id)
      unless pm.nil? || pm.send(config).zero?
        @setting_found = 1
        return false if pm.send(config) == 1
        return true if pm.send(config) == 2
        # 0 = use system based settings
      end
      default_project_setting(proj, config)
    end

    def default_project_setting(proj, config)
      if proj.present? && proj.parent.present?
        parent_setting = setting_for_project proj.parent, config
        return parent_setting if @setting_found == 1
      end
      # system based
      return true if RedmineMessenger.settings[config].present? && RedmineMessenger.setting?(config)

      false
    end

    def attachment_text_from_journal(journal)
      obj = journal.details.detect { |j| j.prop_key == 'description' && j.property == 'attr' }
      text = obj.value if obj.present?
      text.present? ? markup_format(text) : nil
    end

    def detail_to_field(detail, prj = nil)
      field_format = nil
      key = nil
      escape = true
      value = detail.value.to_s
      if detail.property == 'cf'
        key = CustomField.find(detail.prop_key)&.name
        unless key.nil?
          title = key
          field_format = CustomField.find(detail.prop_key)&.field_format

          value = IssuesController.helpers.format_value(detail.value, detail.custom_field) if detail.value.present?
        end
      elsif detail.property == 'attachment'
        key = 'attachment'
        title = I18n.t :label_attachment
        value = detail.value.to_s
      elsif detail.property == 'attr' &&
            detail.prop_key == 'db_relation'
        return { short: true } unless setting_for_project(prj, :post_db)

        title = I18n.t :field_db_relation
        if detail.value.present?
          entry = DbEntry.visible.find_by id: detail.value
          value = entry.present? ? entry.name : detail.value.to_s
        end
      elsif detail.property == 'attr' &&
            detail.prop_key == 'password_relation'
        return { short: true } unless setting_for_project(prj, :post_password)

        title = I18n.t :field_password_relation
        if detail.value.present?
          entry = Password.visible.find_by id: detail.value
          value = entry.present? ? entry.name : detail.value.to_s
        end
      else
        key = detail.prop_key.to_s.sub('_id', '')
        title = case key
                when 'parent'
                  I18n.t "field_#{key}_issue"
                when 'copied_from'
                  I18n.t "label_#{key}"
                else
                  I18n.t "field_#{key}"
                end
        value = detail.value.to_s
      end

      short = true
      case key
      when 'title', 'subject'
        short = false
      when 'description'
        return
      when 'tracker'
        value = object_field_value Tracker, detail.value
      when 'estimated_hours'
        value = format_hours(value.is_a?(String) ? (value.to_hours || value) : value)
      when 'project'
        value = object_field_value Project, detail.value
      when 'status'
        value = object_field_value IssueStatus, detail.value
      when 'priority'
        value = object_field_value IssuePriority, detail.value
      when 'category'
        value = object_field_value IssueCategory, detail.value
      when 'assigned_to', 'author'
        value = object_field_value Principal, detail.value
      when 'fixed_version'
        value = object_field_value Version, detail.value
      when 'attachment'
        attachment = Attachment.find_by id: detail.prop_key
        value = if attachment.present?
                  escape = false
                  "<#{object_url attachment}|#{markup_format attachment.filename}>"
                else
                  detail.prop_key.to_s
                end

      when 'parent', 'copied_from'
        issue = Issue.find_by id: detail.value
        value = if issue.present?
                  escape = false
                  "<#{object_url issue}|#{markup_format issue}>"
                else
                  detail.value.to_s
                end
      end

      value = object_field_value(Version, detail.value) if detail.property == 'cf' && field_format == 'version'
      value = if value.present?
                if escape
                  markup_format value
                else
                  value
                end
              else
                '-'
              end

      result = { title: title, value: value }
      result[:short] = true if short
      result
    end

    def mentions(project, text)
      names = []
      textfield_for_project(project, :default_mentions).split(',').each { |m| names.push m.strip }
      names += extract_usernames(text) unless text.nil?
      names.present? ? " To: #{names.uniq.join ', '}" : nil
    end

    private

    def object_field_value(klass, id)
      obj = klass.find_by id: id
      obj.nil? ? id.to_s : obj.to_s
    end

    def extract_usernames(text)
      text = '' if text.nil?
      # messenger usernames may only contain lowercase letters, numbers,
      # dashes, dots and underscores and must start with a letter or number.
      text.scan(/@[a-z0-9][a-z0-9_\-.]*/).uniq
    end

    def default_project_channels(proj)
      # parent project based
      parent_channel = channels_for_project proj.parent
      return parent_channel if parent_channel.present?
      # system based
      if RedmineMessenger.settings[:messenger_channel].present? &&
         RedmineMessenger.settings[:messenger_channel] != '-'
        return RedmineMessenger.settings[:messenger_channel].split(',').map!(&:strip).uniq
      end

      []
    end
  end
end
