class BoardsController < DashboardsController
  def index
    # For now, just redirect to the first board (IT Operations)
    redirect_to board_path(Board.first)
  end

  def show
    @board = Board.includes(lists: { cards: [ :referenceable, :users ] }).find(params[:id])
  end
end
