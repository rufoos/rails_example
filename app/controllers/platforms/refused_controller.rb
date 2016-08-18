class Platforms::RefusedController < ApplicationController
  include PlatformsConcern

  before_action :authenticate_user!
  before_action :set_platform

  respond_to :js
  layout false

  def new
    respond_with(@platform)
  end
  
  def update
    authorize @platform
    @platform.update_columns(refused_params.merge(platform_status: :refused, moder_id: current_user.id))
    @platform.send_refuse_notification
    respond_to do |format|
      format.js { render partial: 'platforms/change_status' }
    end
  end

  private

  def refused_params
    params.require(:platform).permit(:reason_refuse, :refuse_comment)
  end

end