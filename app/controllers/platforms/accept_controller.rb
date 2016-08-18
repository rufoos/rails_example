class Platforms::AcceptController < ApplicationController
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
    updated = @platform.update(refused_params.merge(platform_status: :accepted, moder_id: current_user.id))
    flash[:error] = t('platforms.flash.not_accepted') unless updated
    respond_to do |format|
      format.js { render partial: updated ? 'platforms/change_status' : 'not_updated' }
    end
  end

  private

  def refused_params
    params.require(:platform).permit(:reason_accept)
  end

end