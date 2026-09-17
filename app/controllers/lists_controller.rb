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
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              # Append the new list to the board container
              turbo_stream.append("lists-container", partial: "lists/list", locals: { list: @list, cards: [], filtered: false }),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Column created." })
            ]
          else
            redirect_to board_path(@board), notice: "Column added.", status: :see_other
          end
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
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            head :ok
          else
            redirect_to board_path(@list.board), notice: "Column updated.", status: :see_other
          end
        end
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
          turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Column deleted." })
        ]
      end
    end
  end

  def move
    position = params[:position].to_i
    unless position.positive?
      return render json: { errors: "Position must be greater than 0." }, status: :unprocessable_entity
    end

    @list.insert_at(position)
    @list.board.touch # Trigger morph refresh
    head :ok
  end

  def select_options
    # Fetch lists for the board, ordered by their position (Left to Right)
    @lists = List.where(board_id: params[:board_id]).order(:position)

    if (frame_id = request.headers["Turbo-Frame"].presence)
      render turbo_stream: turbo_stream.update(frame_id, partial: "lists/select_options", locals: { lists: @lists })
    else
      render partial: "lists/select_options", locals: { lists: @lists }
    end
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
