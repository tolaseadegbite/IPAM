class SearchController < ApplicationController
  def index
    if params[:query].present?
      # 1. Perform the search
      # 2. 'includes(:searchable)' prevents N+1 queries by preloading the actual Device/Employee records
      @results = PgSearch.multisearch(params[:query]).includes(:searchable)
    else
      @results = []
    end
  end
end