class IpAddressesController < ApplicationController
  before_action :set_ip_address, only: %i[ show edit update ]

  def index
    records = IpAddress.includes(:subnet, :device).order(:address)
    @search = records.ransack(params[:q])
    @pagy, @ip_addresses = pagy(@search.result)
  end

  def show
  end

  def edit
  end

  def update
    if @ip_address.update(ip_address_params)
      respond_to do |format|
        format.html { redirect_to ip_addresses_path, notice: "IP Address updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@ip_address, partial: "ip_addresses/ip_address", locals: { ip_address: @ip_address }),
            turbo_stream.update(("details"), partial: "ip_addresses/details"),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "IP Address updated." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def select_options
    # Fetch ONLY free IPs for the selected subnet
    @ip_addresses = IpAddress.where(subnet_id: params[:subnet_id]).free.order(:address)

    render partial: "ip_addresses/select_options", locals: { ip_addresses: @ip_addresses }
  end

  private
    def set_ip_address
      @ip_address = IpAddress.find(params[:id])
    end

    def ip_address_params
      params.require(:ip_address).permit(:status, :device_id, :notes)
    end
end
