class IpAddressesController < ApplicationController
  before_action :set_ip_address, only: %i[ show edit update reclaim ]

  def index
    records = IpAddress.includes(:subnet, device: :employee).order(:address)
    @search = records.ransack(params[:q])
    @pagy, @ip_addresses = pagy(@search.result)
  end

  def show
    # Fetch history efficiently
    @cards = @ip_address.cards.includes(:list, :users).order(created_at: :desc)
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
            turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "IP Address updated." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # One-click reclaim from the dashboard attention queue. Releases the
  # device and frees the address, then dismisses the queue row.
  def reclaim
    if @ip_address.update(status: :available, device_id: nil)
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "IP #{@ip_address.address} reclaimed." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(params[:row_id]),
            turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "IP #{@ip_address.address} reclaimed." })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to dashboard_path, alert: @ip_address.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals: { alert: @ip_address.errors.full_messages.to_sentence }), status: :unprocessable_entity
        end
      end
    end
  end

  def select_options
    # Fetch ONLY free IPs for the selected subnet
    @ip_addresses = IpAddress.where(subnet_id: params[:subnet_id]).free.order(:address)

    render partial: "ip_addresses/select_options", locals: { ip_addresses: @ip_addresses }
  end

  private
    def set_ip_address
      @ip_address = IpAddress.includes(:subnet, :device).find(params[:id])
    end

    def ip_address_params
      params.require(:ip_address).permit(:status, :device_id, :notes)
    end
end
