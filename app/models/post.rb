class Post < ActiveRecord::Base
  include Tasks
  belongs_to :platform
  belongs_to :campaign
  belongs_to :campaign_platform
  has_many :screenshots

  POST_LINK_VK = 'https://vk.com/wall-%s_%s'
  POST_LINK_FB = 'https://fb.com/%s/posts/%s'
  POST_LINK_OK = 'https://ok.ru/group/%s/topic/%s'

  POST_ID_VK = '-%s_%s'
  POST_ID_OK = '%s'
  POST_ID_FB = '%s_%s'

  enum platform_type: {
    "#{Platform::SITE}" => 1,
    "#{Platform::VKPUBLIC}" => 2,
    "#{Platform::OKGROUP}" => 3,
    "#{Platform::FBPAGE}" => 4
  }

  scope :campaign_platforms, ->{ select('posts.*, campaign_platforms.plays_current AS plays_current').joins(campaign: :campaign_platforms).where('campaign_platforms.platform_id = posts.platform_id') }
  scope :filter, ->(params){
    q_params = []
    query = []
    unless params.empty?
      params.each do |key, value|
        next if value.blank?
        case key
        when 'referer_url'
          query.push("#{key} LIKE ?")
          q_params.push("%#{value}%")
          else
          query.push(value.is_a?(Array) ? "#{key} IN (?)" : "#{key} = ?")
          q_params.push(Post.platform_types[value])
        end
      end
      where(sanitize_sql_array([query.join(' AND ')] + q_params))
    end
  }

  # Запрос суммирует лайки, репосты, id пользователей кто лайкнул и кто репостнул
  # по всем размещениям какие были и показывает последнее размещение по дате date_add
  scope :grouped_for_old_posts, ->(campaign_id){
    select('posts.id,
      posts.campaign_platform_id,
      posts.platform_id,
      posts.platform_group_id,
      posts.platform_post_id,
      posts.platform_type,
      posts.campaign_id,
      posts.referer_url,
      posts.date_add,
      posts.date_checked,
      posts.description_hash,
      posts.deleted,
      posts.created_at,
      posts.updated_at,
      posts.cnt,
      posts.date_repost,
      p1.likes AS likes,
      p1.reposts AS reposts,
      p1.who_likes_ids AS who_likes_ids,
      p1.who_repost_ids AS who_repost_ids').
    joins("JOIN (
      SELECT
          platform_id,
          MAX(date_add) AS max_date_add,
          SUM(likes) AS likes,
          SUM(reposts) AS reposts,
          IF(who_likes_ids != '', GROUP_CONCAT(who_likes_ids SEPARATOR ','), '') AS who_likes_ids,
          IF(who_repost_ids != '', GROUP_CONCAT(who_repost_ids SEPARATOR ','), '') AS who_repost_ids
        FROM posts WHERE campaign_id = #{campaign_id} GROUP BY platform_id
    ) AS p1 ON posts.platform_id = p1.platform_id AND posts.date_add = p1.max_date_add")
  }

  def clean_referer_url
    referer_url.gsub(/(http:\/\/|https:\/\/|www[\.]?)/, '')
  end

  def take_screenshot
    return if platform.nil? || campaign.nil?

    shot_urls = if platform.is_social_platform?
      [url, platform.url]
    else
      [referer_url.blank? ? url : referer_url]
    end

    shot_urls.each do |shot_url|
      shot_url = shot_url.gsub(/(http:\/\/|https:\/\/|www[\.]?)/, '')
      date_stamp = DateTime.current
      screenshot_file_path = "screenshot_#{platform.id}_#{campaign.id}_#{date_stamp.to_i}_"
      screenshot_params = [
        'T5', # Таймаут 5 секунд
        "#{Screenshot::WIDTH}x#{Screenshot::HEIGHT}",
        "#{Screenshot::WIDTH_OUT}",
        "#{Screenshot::EXT}"
      ]
      if platform.is_site?
        screenshot_params << "UA(Ruby; rtrCampaignId=#{campaign.id})"
      end

      tempfile = Screenshot.make_screenshot(shot_url, screenshot_file_path, screenshot_params)

      screenshot = screenshots.where(
        campaign_id: campaign.id,
        platform_id: platform.id,
        url: shot_url
      ).first
      if screenshot
        screenshot.update({
          attempts: screenshot.attempts + 1,
          date_attempt_last: date_stamp,
          aasm_state: (tempfile.nil? ? :refused : :success),
          file: tempfile
        })
      else
        screenshot = screenshots.build(
          campaign_id: campaign.id,
          platform_id: platform.id,
          url: shot_url,
          shoot_at: date_stamp,
          attempts: 1,
          date_attempt_last: date_stamp,
          aasm_state: (tempfile.nil? ? :refused : :success),
          file: tempfile
        )
        screenshot.save
      end
      
      tempfile.close unless tempfile.nil?
    end
  end

  def url
    return nil unless platform
    case platform.type
      when Platform::SITE
        referer_url
      when Platform::VKPUBLIC
        POST_LINK_VK % [platform_group_id, platform_post_id]
      when Platform::OKGROUP
        POST_LINK_OK % [platform_group_id, platform_post_id]
      when Platform::FBPAGE
        POST_LINK_FB % [platform_group_id, platform_post_id]
      else
        referer_url
    end
  end

end
