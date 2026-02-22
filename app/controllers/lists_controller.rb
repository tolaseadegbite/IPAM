class ListsController < ApplicationController
  before_action :set_board, only: %i[ new create ]
  before_action :set_list, only: %i[ edit update destroy move ]

  def new
    @list = @board.lists.new
  end

  def edit
  end

  def create
    @list = @board.lists.new(list_params)

    if @list.save
      respond_to do |format|
        format.html { redirect_to board_path(@board), notice: "Column added." }
        format.turbo_stream do
          render turbo_stream: [
            # Append the new list to the board container
            turbo_stream.append("lists-container", partial: "lists/list", locals: { list: @list }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Column created." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @list.update(list_params)
      # Rely on Board broadcasts_refreshes (Morphing) to update the name
      respond_to do |format|
        format.html { redirect_to board_path(@list.board), notice: "Column updated." }
        format.turbo_stream { head :ok }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    board = @list.board
    @list.destroy
    respond_to do |format|
      format.html { redirect_to board_path(board), notice: "Column removed." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@list)),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Column deleted." })
        ]
      end
    end
  end

  def move
    @list.insert_at(params[:position].to_i)
    @list.board.touch # Trigger morph refresh
    head :ok
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_list
    @list = List.find(params[:id])
  end

  def list_params
    params.require(:list).permit(:name)
  end
end
