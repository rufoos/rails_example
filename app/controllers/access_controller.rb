class AccessController < ApplicationController
  before_filter :authenticate_user!
  before_action :set_access
  after_action :verify_authorized

  def show
    authorize @access
    @campaign = @access.campaign
    @platform = @access.platform
    @statistic_by_days = @campaign.stat_days.for(@platform.webmaster).where(platform_id: @platform.id).group(:date)
    @statistic_by_hours = @campaign.stat_hours.for(@platform.webmaster).where(platform_id: @platform.id).group(:datetime, :stat_type).order(:datetime)
    respond_to do |format|
      format.js
    end
  end

  def destroy
    authorize @access
    if @access.plays_current == 0 && @access.posts.empty?
      @access.destroy
    end
  end

  private

  def set_access
    @access = CampaignPlatform.where(id: params[:id]).includes(:platform, :campaign).first
  end

end