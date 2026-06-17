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

    sanitize markdown.render(text.to_s)
  end

  private

  def partial_for(prefix:, name:)
    normalized = name.to_s.underscore.tr("-", "_")
    if normalized.present? && lookup_context.exists?(normalized, [ prefix ], true)
      "#{prefix}/#{normalized}"
    else
      "#{prefix}/default"
    end
  end
end
