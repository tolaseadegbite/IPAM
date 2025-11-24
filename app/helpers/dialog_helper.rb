module DialogHelper
  # Renders a complete dialog component including a trigger and modal.
  #
  # - trigger: The HTML for the button or link that opens the dialog.
  # - title:   The text to display in the dialog's h2 tag.
  # - label:   The accessible name for the dialog (defaults to title).
  # - size:    The max-width of the dialog (e.g., '500px').
  # - &block:  The content to be rendered inside the dialog body.
  #
  def modal_dialog(trigger, title: nil, label: nil, size: nil, &block)
    # The 'capture' method takes the block from the view and renders it as a string.
    content = capture(&block) if block

    # Render the generic partial, passing all our pieces as local variables.
    render "shared/dialog",
      trigger: trigger,
      title:   title,
      label:   label || title, # Use title as a fallback for the ARIA label
      size:    size,
      content: content
  end
end