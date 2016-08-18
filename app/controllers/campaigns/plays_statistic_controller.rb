class Campaigns::PlaysStatisticController < ApplicationController
  before_filter :authenticate_user!
  
  layout false
  respond_to :js

  def index
    @campaign = Campaign.find(params[:campaign_id])
    @plays_statistic = @campaign.stat_hours_or_minutes
  end

end