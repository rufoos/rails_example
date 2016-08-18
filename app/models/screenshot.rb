require 'net/http'
class Screenshot < ActiveRecord::Base
  include AASM
  
  mount_uploader :file, ScreenshotUploader

  # Документация: http://www.s-shot.ru/doc_extended/
  SHOTER_URL = "http://api.s-shot.ru/"
  WIDTH = 1024
  HEIGHT = 3000
  WIDTH_OUT = 1024
  EXT = 'jpeg'

  ARCHIVE_PATH = "#{Rails.root}/shared/screenshots/"

  belongs_to :campaign
  belongs_to :platform
  belongs_to :post

  scope :not_mades, ->{ where(aasm_state: [:pending, :refused]) }

  aasm do # defaults to aasm_state
    state :pending, :initial => true
    state :success
    state :refused
    event :success do
      transitions :to => :success, :from => [ :pending, :refused ]
    end
    event :refused do
      transitions :to => :refused, :from => [ :pending, :success ]
    end
  end

  def status
    aasm_state
  end

  def self.task_take_screenshots
    Screenshot.pending.includes(:post).each do |screenshot|
      unless screenshot.post
        screenshot.aasm_state = 'refused'
        screenshot.attempts += 1
        screenshot.save
        Rails.logger.error("Take screenshot: Post not found for #{screenshot.inspect}")
        next
      end
      screenshot.post.take_screenshot
    end
  end

  def self.make_screenshot(shot_url, file_name, screenshot_params)
    tempfile = nil
    uri = URI(SHOTER_URL)
    request = Net::HTTP::Get.new(SHOTER_URL + screenshot_params.join('/') + "/?#{shot_url}")
    Net::HTTP.start(uri.hostname, uri.port){ |http|
      response = http.request(request)
      tempfile = Tempfile.new([file_name, ".#{Screenshot::EXT}"])
      File.open(tempfile.path, 'wb') do |f|
        f.write response.body
      end
    }
    tempfile
  end

end
