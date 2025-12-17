class VersionsController < ApplicationController
  def index
    # Start with all versions, sorted newest first
    @versions = PaperTrail::Version.order(created_at: :desc)

    # Filter: If we are looking at a specific item (e.g., Device #1)
    if params[:item_type].present? && params[:item_id].present?
      @versions = @versions.where(item_type: params[:item_type], item_id: params[:item_id])
      
      # Fetch the actual item name for the header (optional, nice to have)
      # We use .find_by so it doesn't crash if the item was deleted
      item_class = params[:item_type].safe_constantize
      @item = item_class.find_by(id: params[:item_id]) if item_class
    end

    # Use Pagy to handle the pagination (e.g., 50 per page)
    @pagy, @versions = pagy(@versions, items: 50)
  end
end