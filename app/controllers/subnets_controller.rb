class SubnetsController < ApplicationController
  before_action :set_subnet, only: %i[ show edit update destroy ]

  def index
    records = Subnet.all.order(:name)
    @search = records.ransack(params[:q])
    @pagy, @subnets = pagy(@search.result)
  end

  def show
    @ip_addresses = @subnet.ip_addresses.includes(:device).order(:address)
  end

  def new
    @subnet = Subnet.new
  end

  def edit
  end

  def create
    @subnet = Subnet.new(subnet_params)

    if @subnet.save

      respond_to do |format|
        format.html { redirect_to subnets_path, notice: "Subnet created successfully." }
        format.turbo_stream do
          render turbo_stream: [
             turbo_stream.prepend("subnets-table", partial: "subnets/subnet", locals: { subnet: @subnet }),
            turbo_stream.prepend("subnets-cards", partial: "subnets/subnet_card", locals: { subnet: @subnet }),
            turbo_stream.update("new_subnet", ""), # Clear the form/modal
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Subnet created successfully." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @subnet.update(subnet_params)
      respond_to do |format|
        format.html { redirect_to subnets_path, notice: "Subnet updated successfully." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@subnet, :table_row), partial: "subnets/subnet", locals: { subnet: @subnet }),
            turbo_stream.replace(helpers.dom_id(@subnet, :card), partial: "subnets/subnet_card", locals: { subnet: @subnet }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Subnet updated successfully." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @subnet.destroy
    respond_to do |format|
      format.html { redirect_to subnets_path, notice: "Subnet deleted." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@subnet, :table_row)),
          turbo_stream.remove(helpers.dom_id(@subnet, :card)),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Subnet deleted." })
        ]
      end
    end
  end

  private
    def set_subnet
      @subnet = Subnet.find(params[:id])
    end

    def subnet_params
      params.require(:subnet).permit(:name, :network_address, :gateway, :vlan_id)
    end
end
