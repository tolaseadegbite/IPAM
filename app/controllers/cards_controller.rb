class CardsController < ApplicationController
  before_action :set_card, only: %i[ edit update destroy move ]

  def new
    @card = Card.new(list_id: params[:list_id])

    # Handle incoming polymorphic references (from Device/IP pages)
    if params[:referenceable_type] && params[:referenceable_id]
      @card.referenceable_type = params[:referenceable_type]
      @card.referenceable_id = params[:referenceable_id]

      ref_object = params[:referenceable_type].constantize.find(params[:referenceable_id])
      @card.title = "Issue with #{ref_object.respond_to?(:name) ? ref_object.name : ref_object.address}"
    end
  end

  def edit
    # Fetch the history logs, most recent first
    @versions = @card.versions.order(created_at: :desc)
  end

  def create
    @card = Card.new(card_params)

    if @card.save
      respond_to do |format|
        format.html { redirect_to board_path(@card.list.board), notice: "Task created." }
        format.turbo_stream do
          render turbo_stream: [
            # 1. Append the new card to the specific list's container
            turbo_stream.append(helpers.dom_id(@card.list, :cards), partial: "cards/card", locals: { card: @card }),
            # 2. Close the modal by emptying the frame
            turbo_stream.update("modal", ""),
            # 3. Flash message
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Task created successfully." })
          ]
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
          streams = [
            turbo_stream.update("modal", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Task updated successfully." })
          ]

          # Visual Logic: Did it move to a new column or stay in the same one?
          if old_list_id == @card.list_id
            streams << turbo_stream.replace(helpers.dom_id(@card), partial: "cards/card", locals: { card: @card })
          else
            streams << turbo_stream.remove(helpers.dom_id(@card))
            streams << turbo_stream.append(helpers.dom_id(@card.list, :cards), partial: "cards/card", locals: { card: @card })
          end

          render turbo_stream: streams
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
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Task deleted." }),
          turbo_stream.update("modal", "") # Just in case deleted from within a modal
        ]
      end
    end
  end

  def move
    @card.update(
      list_id: params[:list_id],
      position: params[:position]
    )
    # The Board broadcasts_refreshes (Morphing) handles the remote sync
    head :ok
  end

  def select_assets
    @asset_type = params[:asset_type]

    case @asset_type
    when "Device"
      # Eager load department and branch for the smart label
      @assets = Device.includes(department: :branch).active.order(:name).map do |d|
        [ "#{d.name} (#{d.department.branch.name} - #{d.department.name})", d.id ]
      end
      render partial: "cards/asset_selectors/asset_combobox", locals: { assets: @assets, prompt: "Search by Hostname..." }

    when "IpAddress"
      # Eager load subnet for the smart label
      @assets = IpAddress.includes(:subnet).order(:address).map do |ip|
        [ "#{ip.address} (#{ip.subnet.name})", ip.id ]
      end
      render partial: "cards/asset_selectors/asset_combobox", locals: { assets: @assets, prompt: "Search by IP Address..." }

    else
      render turbo_stream: turbo_stream.update("asset_options_frame", "")
    end
  end

  private

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
