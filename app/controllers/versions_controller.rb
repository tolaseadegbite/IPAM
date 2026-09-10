class VersionsController < ApplicationController
  before_action :require_admin

  # Ransack is intentionally not used here: PaperTrail::Version exposes no
  # allowlists, and four explicit filters cover the audit use cases.
  ITEM_TYPES = %w[Branch Department Employee Device IpAddress Subnet User].freeze
  EVENTS = %w[create update destroy].freeze

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

    if EVENTS.include?(params[:event].to_s)
      @versions = @versions.where(event: params[:event])
    end

    if ITEM_TYPES.include?(params[:filter_item_type].to_s)
      @versions = @versions.where(item_type: params[:filter_item_type])
    end

    if params[:username].present?
      user_ids = User.where("username ILIKE ?", "%#{params[:username].gsub(/[%_]/, "")}%").select(:id)
      @versions = @versions.where(whodunnit: user_ids)
    end

    if params[:from].present?
      @versions = @versions.where("created_at >= ?", params[:from])
    end

    if params[:to].present?
      @versions = @versions.where("created_at <= ?", params[:to])
    end

    # Use Pagy to handle the pagination (e.g., 50 per page)
    @pagy, @versions = pagy(@versions, items: 50)
  end
end
