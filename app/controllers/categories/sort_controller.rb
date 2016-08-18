class Categories::SortController < ApplicationController
  before_action :authenticate_user!
  respond_to :json

  # POST
  def create
    authorize Category, :admin?

    update_data = {}
    sort_params.each do |i, cat|
      update_data.merge!(cat.delete('id').to_i => cat.merge(position: i.to_i + 1))
    end

    updated = Category.update(update_data.keys, update_data.values)
    
    respond_to do |format|
      format.json { render json: { updated: updated } }
    end
  end

private

  def sort_params
    params.require(:categories)
  end
end
