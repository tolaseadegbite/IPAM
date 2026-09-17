class CardsController < ApplicationController
  before_action :set_card, only: %i[ edit update destroy move ]

  # Only these models may be linked to a card.
  REFERENCEABLE_TYPES = %w[Device IpAddress].freeze

  def new
    @card = Card.new(list_id: params[:list_id])

    # Handle incoming polymorphic references (from Device/IP pages)
    if params[:referenceable_type] && params[:referenceable_id] &&
       REFERENCEABLE_TYPES.include?(params[:referenceable_type])
      @card.referenceable_type = params[:referenceable_type]
      @card.referenceable_id = params[:referenceable_id]

      ref_object = params[:referenceable_type].constantize.find(params[:referenceable_id])
      @card.title = "Issue with #{ref_object.respond_to?(:name) ? ref_object.name : ref_object.address}"
    end
  end

  def edit
    # Activity timeline, most recent first (names snapshotted at write
    # time, so rendering is a single query with no lookups).
    @activities = @card.activities.includes(:user).recent
  end

  def create
    @card = Card.new(card_params)

    if @card.save
      respond_to do |format|
        format.html { redirect_to board_path(@card.list.board), notice: "Task created." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              # 1. Append the new card to the specific list's container
              turbo_stream.append(helpers.dom_id(@card.list, :cards), partial: "cards/card", locals: { card: @card }),
              # 2. Close the modal by emptying the frame
              turbo_stream.update("modal", ""),
              # 3. Flash message
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Task created successfully." })
            ]
          else
            redirect_to board_path(@card.list.board), notice: "Task created.", status: :see_other
          end
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Store the old list ID in case they changed columns via the form dropdown
    old_list_id = @card.list_id

    if @card.update(card_params)
      respond_to do |format|
        format.html { redirect_to board_path(@card.list.board), notice: "Task updated." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            streams = [
              turbo_stream.update("modal", ""),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Task updated successfully." })
            ]

            # Visual Logic: Did it move to a new column or stay in the same one?
            if old_list_id == @card.list_id
              streams << turbo_stream.replace(helpers.dom_id(@card), partial: "cards/card", locals: { card: @card })
            else
              streams << turbo_stream.remove(helpers.dom_id(@card))
              streams << turbo_stream.append(helpers.dom_id(@card.list, :cards), partial: "cards/card", locals: { card: @card })
            end

            render turbo_stream: streams
          else
            redirect_to board_path(@card.list.board), notice: "Task updated.", status: :see_other
          end
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    board = @card.list.board
    @card.destroy

    respond_to do |format|
      format.html { redirect_to board_path(board), notice: "Task deleted." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@card)),
          turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Task deleted." }),
          turbo_stream.update("modal", "") # Just in case deleted from within a modal
        ]
      end
    end
  end

  def move
    if @card.update(list_id: params[:list_id], position: params[:position])
      # The Board broadcasts_refreshes (Morphing) handles the remote sync
      head :ok
    else
      render json: { errors: @card.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def select_assets
    @asset_type = params[:asset_type]

    case @asset_type
    when "Device"
      # Eager load department and branch for the smart label.
      # Capped: the combobox filters client-side, and unbounded lists
      # exhaust memory on large inventories.
      # NOTE: intentionally unscoped by status — maintenance tasks are
      # often *about* non-active devices (in repair, retired, lost).
      @assets = Device.includes(department: :branch).order(:name).limit(500).map do |d|
        [ "#{d.name} (#{d.department.branch.name} - #{d.department.name})", d.id ]
      end
      render_asset_options(assets: @assets, prompt: "Search by Hostname...")

    when "IpAddress"
      # Eager load subnet for the smart label (capped, see above).
      @assets = IpAddress.includes(:subnet).order(:address).limit(500).map do |ip|
        [ "#{ip.address} (#{ip.subnet.name})", ip.id ]
      end
      render_asset_options(assets: @assets, prompt: "Search by IP Address...")

    else
      render turbo_stream: turbo_stream.update("asset_options_frame", "")
    end
  end

  private

  def render_asset_options(assets:, prompt:)
    if (frame_id = request.headers["Turbo-Frame"].presence)
      render turbo_stream: turbo_stream.update(frame_id, partial: "cards/asset_selectors/asset_combobox", locals: { assets: assets, prompt: prompt })
    else
      render partial: "cards/asset_selectors/asset_combobox", locals: { assets: assets, prompt: prompt }
    end
  end

  def set_card
    @card = Card.find(params[:id])
  end

  def card_params
    params.require(:card).permit(
      :title, :description, :priority, :list_id,
      :referenceable_type, :referenceable_id, user_ids: []
    )
  end
end
