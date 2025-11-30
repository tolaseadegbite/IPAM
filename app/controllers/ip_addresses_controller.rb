class IpAddressesController < ApplicationController
  before_action :set_ip_address, only: %i[ show edit update destroy ]

  def index
    @ip_addresses = IpAddress.includes(:subnet, :device).order(:address)

    if params[:subnet_id].present?
      @ip_addresses = @ip_addresses.where(subnet_id: params[:subnet_id])
    end

    if params[:status].present?
      @ip_addresses = @ip_addresses.where(status: params[:status])
    end
  end

  def show
  end

  def new
    @ip_address = IpAddress.new
  end

  def edit
  end

  def create
    @ip_address = IpAddress.new(ip_address_params)

    if @ip_address.save
      respond_to do |format|
        format.html { redirect_to ip_addresses_path, notice: "IP Address created successfully." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("ip_addresses", partial: "ip_addresses/ip_address", locals: { ip_address: @ip_address }),
            turbo_stream.update("new_ip_address", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "IP Address created successfully." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ip_address.update(ip_address_params)
      respond_to do |format|
        format.html { redirect_to ip_addresses_path, notice: "IP Address updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@ip_address, partial: "ip_addresses/ip_address", locals: { ip_address: @ip_address }),
            turbo_stream.update(("details"), partial: "ip_addresses/hardware_details"),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "IP Address updated." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ip_address.destroy
    respond_to do |format|
      format.html { redirect_to ip_addresses_path, notice: "IP Address removed." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@ip_address),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "IP Address removed." })
        ]
      end
    end
  end

  private
    def set_ip_address
      @ip_address = IpAddress.find(params[:id])
    end

    def ip_address_params
      # Note: 'address' is usually immutable after creation, but permitted here if manual entry is needed.
      # 'device_id' is permitted so you can manually assign an IP to a device from this view if necessary.
      params.require(:ip_address).permit(:address, :status, :subnet_id, :device_id, :notes)
    end
end
