class Access::BanController < ApplicationController
  before_action :authenticate_user!

  respond_to :json
  layout false

  def update
    access = CampaignPlatform.find(params[:id])
    access.date_ban_toggle!
    respond_to do |format|
      format.json { render json: { date_ban: access.date_ban_stopped } }
    end
  end

end