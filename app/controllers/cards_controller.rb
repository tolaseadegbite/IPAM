class CardsController < ApplicationController
  before_action :set_card, only: %i[ edit update destroy move ]

  def new
    # 1. Standard initialization
    @card = Card.new(list_id: params[:list_id] || List.first&.id)

    # 2. Handle incoming polymorphic references (from Device/IP show pages)
    if params[:referenceable_type] && params[:referenceable_id]
      @card.referenceable_type = params[:referenceable_type]
      @card.referenceable_id = params[:referenceable_id]

      # Optional: Auto-fill the title to save the admin time
      ref_object = params[:referenceable_type].constantize.find(params[:referenceable_id])
      @card.title = "Issue with #{ref_object.respond_to?(:name) ? ref_object.name : ref_object.address}"
    end
  end

  def edit
  end

  def create
    @card = Card.new(card_params)

    if @card.save
      # Redirect to the board this card belongs to
      redirect_to board_path(@card.list.board), notice: "Task created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @card.update(card_params)
      redirect_to board_path(@card.list.board), notice: "Task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    board = @card.list.board
    @card.destroy
    redirect_to board_path(board), notice: "Task deleted."
  end

  def move
    # 1. Update the List (if changed)
    # 2. Update the Position (acts_as_list handles the reordering of neighbors)
    @card.update(
      list_id: params[:list_id],
      position: params[:position]
    )
    head :ok
  end

  private

  def set_card
    @card = Card.find(params[:id])
  end

  def card_params
    # Note: user_ids: [] allows assigning multiple IT staff to a ticket
    params.require(:card).permit(
      :title, :description, :priority, :list_id,
      :referenceable_type, :referenceable_id, user_ids: []
    )
  end
end
