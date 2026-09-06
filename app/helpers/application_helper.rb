module ApplicationHelper
  include Pagy::Frontend

  # returns full title if present, else returns base title
  def full_title(page_title = "")
    base_title = "Mainline"
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

  # Renders an icon from the shared SVG sprite (see shared/_icon_sprite).
  # Example: <%= icon("search", "h-4 w-4 text-zinc-400") %>
  def icon(name, classes = "h-4 w-4")
    tag.svg(class: "shrink-0 #{classes}", "aria-hidden": true) do
      tag.use(href: "#icon-#{name}")
    end
  end
end
