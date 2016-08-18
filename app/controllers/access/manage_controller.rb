class Access::ManageController < ApplicationController
  before_action :authenticate_user!

  respond_to :json
  layout false

  def create
    msg = ''
    result =
      case manage_params[:action]
      when 'delete'
        CampaignPlatform.delete(accesses.map(&:id))
      when 'copy_to_campaign'
        copy_accesses
      end
    respond_to do |format|
      format.json { render json: { result: result, action: manage_params[:action], msg: msg } }
    end
  end

  private

  def manage_params
    params.require(:manage).permit(:access_ids, :action, :to_campaign_id, :select, :with_default_params)
  end

  def accesses
    case manage_params[:select]
    when 'all'
      if manage_params[:action] == 'delete'
        CampaignPlatform.where(campaign_id: params[:campaign_id], plays_current: 0)
      elsif manage_params[:action] == 'copy_to_campaign'
        CampaignPlatform.where(campaign_id: params[:campaign_id])
      end
    when 'selected'
      access_ids = manage_params[:access_ids].split(',').map(&:to_i)
      if manage_params[:action] == 'delete'
        CampaignPlatform.where(id: access_ids, campaign_id: params[:campaign_id], plays_current: 0)
      elsif manage_params[:action] == 'copy_to_campaign'
        CampaignPlatform.where(id: access_ids, campaign_id: params[:campaign_id])
      end
    end
  end

  def copy_accesses
    to_campaign = Campaign.find(manage_params[:to_campaign_id])
    existed_platform_ids = to_campaign.campaign_platforms.select('platform_id').map(&:platform_id)

    # Поля для INSERT
    insert_fields = %w(platform_id campaign_id group_id cost_advert cost_platform plays_max plays_max_day_limit date_posted ci ci_cheat)

    # Формируем массив значений для INSERT
    cp =
      accesses.to_a.delete_if{ |a| existed_platform_ids.include?(a.platform_id) }.map do |a|

        ci =
          if a.platform.user.ci.present?
            a.platform.user.ci
          else
            if manage_params[:with_default_params].present?
              app_config['campaigns']['default']['ci'][a.platform.platform_type.downcase]
            else
              Platform.calculate_compliance_index(accesses.select{ |ac| ac.platform_id == a.platform_id }.first.platform)
            end
          end

        cost_platform = 
          if manage_params[:with_default_params].present?
            to_campaign.cost_platform
          else
            a.cost_platform.zero? ? to_campaign.cost_platform : a.cost_platform
          end

        ci_cheat =
          if a.platform.user && a.platform.user.ci_shear.present?
            a.platform.user.ci_shear
          else
            100
          end

        [
          a.platform_id,
          to_campaign.id,
          to_campaign.id,
          to_campaign.cost_advert,
          cost_platform,
          to_campaign.estimated_plays_max,
          a.platform.estimated_plays_max.zero? ? to_campaign.estimated_plays_max : a.platform.estimated_plays_max,
          "'#{DateTime.current.to_s(:db)}'",
          ci,
          ci_cheat
        ].join(',')
      end
    unless cp.length.zero?
      insert_values = "(#{cp.join('), (')})"
      CampaignPlatform.connection.insert("INSERT INTO `campaign_platforms` (#{insert_fields.join(',')}) VALUES #{insert_values}")
    end

    cp.length
  end

end