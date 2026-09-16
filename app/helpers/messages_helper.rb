module MessagesHelper
  def default_model_display_name
    model_obj = RubyLLM.models.find(RubyLLM.config.default_model) rescue nil
    "Default: #{model_obj&.label || RubyLLM.config.default_model}"
  end

  def tool_result_partial(message)
    name = message.respond_to?(:parent_tool_call) ? message.parent_tool_call&.name.to_s : ""
    partial_for(prefix: "messages/tool_results", name: name)
  end

  def tool_call_partial(tool_call)
    partial_for(prefix: "messages/tool_calls", name: tool_call.name.to_s)
  end

  def render_markdown(text)
    return "" if text.blank?

    text = linkify_entities(text.to_s)

    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(
      hard_wrap: false,
      escape_html: true
    ), {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true
    })

    sanitize markdown.render(text), tags: MARKDOWN_ALLOWED_TAGS
  end

  private

  MARKDOWN_ALLOWED_TAGS = (
    ActionView::Base.sanitized_allowed_tags.to_a +
    %w[table thead tbody tfoot tr th td]
  ).freeze

  # Linkify IPs/device names in prose only: code spans and fenced blocks
  # keep literal text, otherwise generated [...](...) links show verbatim
  # inside rendered code.
  def linkify_entities(text)
    segments = text.split(/(```.*?```|`[^`\n]*`)/m)
    segments.map.with_index { |segment, index| index.odd? ? segment : linkify_prose(segment) }.join
  end

  def linkify_prose(text)
    ip_ids = IpAddress.pluck(:address, :id).to_h { |addr, id| [ addr.to_s, id ] }
    text = text.gsub(/\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/) do |match|
      ip_ids[match] ? "[#{match}](/ip_addresses/#{ip_ids[match]})" : match
    end

    device_ids = Device.pluck(:name, :id).to_h { |name, id| [ name, id ] }
    device_names = device_ids.keys.sort_by { |n| -n.length }
    if device_names.any?
      device_regex = /\b(?:#{Regexp.union(device_names).source})\b/
      text = text.gsub(device_regex) do |match|
        "[#{match}](/devices/#{device_ids[match]})"
      end
    end

    text
  end

  def partial_for(prefix:, name:)
    normalized = name.to_s.underscore.tr("-", "_")
    if normalized.present? && lookup_context.exists?(normalized, [ prefix ], true)
      "#{prefix}/#{normalized}"
    else
      "#{prefix}/default"
    end
  end
end
