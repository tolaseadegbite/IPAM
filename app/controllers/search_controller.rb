class SearchController < ApplicationController
  def index
    if params[:query].present?
      # Capped: multisearch can match broadly; the page is a preview list.
      @results = PgSearch.multisearch(params[:query]).includes(:searchable).limit(50)
    else
      @results = []
    end
  end
end
