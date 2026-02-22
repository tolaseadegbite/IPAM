class BoardsController < ApplicationController
  before_action :set_board, only: %i[ show edit update destroy ]

  def index
    @boards = Board.includes(lists: :cards).order(created_at: :desc)
    @board = Board.new # For the modal/form initialization
  end

  def show
    @board = Board.includes(lists: { cards: [ :referenceable, :users ] }).find(params[:id])
  end

  def new
    @board = Board.new
  end

  def edit
  end

  def create
    @board = Board.new(board_params)

    if @board.save
      # Auto-create default columns
      [ "To Do", "In Progress", "Done" ].each { |name| @board.lists.create!(name: name) }

      respond_to do |format|
        format.html { redirect_to boards_path, notice: "Board created." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("boards-grid", partial: "boards/board", locals: { board: @board }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Board created successfully." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @board.update(board_params)
      respond_to do |format|
        format.html { redirect_to boards_path, notice: "Board updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@board), partial: "boards/board", locals: { board: @board }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Board updated successfully." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @board.destroy
    respond_to do |format|
      format.html { redirect_to boards_path, notice: "Board deleted." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@board)),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Board deleted." })
        ]
      end
    end
  end

  private

  def set_board
    @board = Board.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, :description)
  end
end
