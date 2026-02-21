class CardsController < DashboardsController
  def move
    @card = Card.find(params[:id])

    # 1. Update the List (if changed)
    # 2. Update the Position (acts_as_list handles the reordering of neighbors)
    @card.update(
      list_id: params[:list_id],
      position: params[:position]
    )

    # No need to render anything, Stimulus handled the visual move.
    head :ok
  end
end
