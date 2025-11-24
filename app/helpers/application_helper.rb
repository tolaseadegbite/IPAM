module ApplicationHelper

  # returns full title if present, else returns base title
  def full_title(page_title = "")
    base_title = "Trellixe"
    if page_title.blank?
      base_title
    else
      "#{page_title} - #{base_title}"
    end
  end
end