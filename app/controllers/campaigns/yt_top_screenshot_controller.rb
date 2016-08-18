class Campaigns::YtTopScreenshotController < ApplicationController
  before_filter :authenticate_user!
  
  def show
    campaign = Campaign.find(params[:id])
    authorize campaign.yt_top_screenshot
    if campaign.yt_top_screenshot && campaign.yt_top_screenshot.file.url && campaign.yt_top_screenshot.file.file.exists?
      send_file(campaign.yt_top_screenshot.file.url, disposition: 'inline')
    else
      not_found
    end
  end

end