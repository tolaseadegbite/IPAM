class ListsController < ApplicationController
  def move
    @list = List.find(params[:id])

    # acts_as_list handles the reordering of the other lists in the board
    @list.insert_at(params[:position].to_i)

    # No need to render anything; Board morphing handles the UI update
    head :ok
  end
end
