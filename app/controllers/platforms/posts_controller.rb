class Platforms::PostsController < ApplicationController
  before_action :authenticate_user!

  respond_to :js
  layout false
  
  def index
    @access = CampaignPlatform.where(id: params[:access_id]).includes(:platform).first
    @posts = Post.where(campaign_id: params[:campaign_id], platform_id: params[:platform_id]).order('posts.date_add DESC')
  end

end