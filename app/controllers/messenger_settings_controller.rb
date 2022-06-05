# frozen_string_literal: true

class MessengerSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def update
    setting = MessengerSetting.find_or_create @project.id
    if setting.update allowed_params
      flash[:notice] = l :notice_successful_update
      redirect_to settings_project_path(@project, tab: 'messenger')
    else
      flash[:error] = setting.errors.full_messages.flatten.join "\n"
      respond_to do |format|
        format.html { redirect_back_or_default(settings_project_path(@project, tab: 'messenger')) }
        format.api  { render_validation_errors setting }
      end
    end
  end

  private

  def allowed_params
    params.require(:setting).permit :messenger_url,
                                    :messenger_icon,
                                    :messenger_channel,
                                    :messenger_username,
                                    :messenger_verify_ssl,
                                    :messenger_direct_users_messages,
                                    :filter_status,
                                    :auto_mentions,
                                    :default_mentions,
                                    :display_watchers,
                                    :post_updates,
                                    :new_include_description,
                                    :updated_include_description,
                                    :post_private_issues,
                                    :post_private_notes,
                                    :post_wiki,
                                    :post_wiki_updates,
                                    :post_db,
                                    :post_db_updates,
                                    :post_private_db,
                                    :post_contact,
                                    :post_contact_updates,
                                    :post_private_contacts,
                                    :post_password,
                                    :post_password_updates
  end
end
