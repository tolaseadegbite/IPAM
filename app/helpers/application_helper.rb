module ApplicationHelper
  include Pagy::Frontend

  # returns full title if present, else returns base title
  def full_title(page_title = "")
    base_title = "IPAM"
    if page_title.blank?
      base_title
    else
      "#{page_title} - #{base_title}"
    end
  end

  def active_for(target_controller)
    if controller_name == target_controller
      { current: "page" }
    else
      {}
    end
  end
end
