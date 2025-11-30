class DevicesController < ApplicationController
  before_action :set_device, only: %i[ show edit update destroy ]

  def index
    records = Device.includes(:department, :employee, :ip_address).order(:serial_number)
    @search = records.ransack(params[:q])
    @pagy, @devices = pagy(@search.result)
  end

  def show
  end

  def new
    @device = Device.new
  end

  def edit
  end

  def create
    @device = Device.new(device_params)

    # We capture the selected IP ID from the form (not a standard column on Device)
    selected_ip_id = params[:device][:ip_address_id]

    Device.transaction do
      if @device.save
        if selected_ip_id.present?
          ip = IpAddress.find_by(id: selected_ip_id)
          # Claim the IP
          ip&.update!(device: @device, status: :active)
        end

        respond_to do |format|
        format.html { redirect_to devices_path, notice: "Device registered." }
        format.turbo_stream do
          render turbo_stream: [
             turbo_stream.prepend("devices-table", partial: "devices/device", locals: { device: @device }),
            turbo_stream.prepend("devices-cards", partial: "devices/device_card", locals: { device: @device }),
            turbo_stream.update("new_device", ""), # Clear the form/modal
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Device registered." })
          ]
        end
      end
      else
        render :new, status: :unprocessable_entity
        raise ActiveRecord::Rollback # Cancel transaction if device save fails
      end
    end
  end

  def update
    selected_ip_id = params[:device][:ip_address_id]

    Device.transaction do
      if @device.update(device_params)

        # IP Re-assignment Logic
        if selected_ip_id.present? && @device.ip_address&.id != selected_ip_id.to_i
          # Release old IP
          @device.ip_address&.update!(device: nil, status: :available)
          # Claim new IP
          new_ip = IpAddress.find_by(id: selected_ip_id)
          new_ip&.update!(device: @device, status: :active)
        end

        respond_to do |format|
          format.html { redirect_to devices_path, notice: "device updated successfully." }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@device, :table_row), partial: "devices/device", locals: { device: @device }),
              turbo_stream.replace(helpers.dom_id(@device, :card), partial: "devices/device_card", locals: { device: @device }),
              turbo_stream.update(("name_and_serial"), partial: "devices/name_and_serial"),
              turbo_stream.update(("hardware_details"), partial: "devices/hardware_details"),
              turbo_stream.update(("network_and_owner_cards"), partial: "devices/network_and_owner_cards"),
              turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Device updated." })
            ]
          end
        end
      else
        render :edit, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def destroy
    # Dependent :nullify in model handles IP release
    @device.destroy
    if @device.destroy
      respond_to do |format|
        format.html { redirect_to devices_path, notice: "Device deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(helpers.dom_id(@device, :table_row)),
            turbo_stream.remove(helpers.dom_id(@device, :card)),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Device deleted." })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to devices_path, alert: @device.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: @device.errors.full_messages.to_sentence })
        end
      end
    end
  end

  private
    def set_device
      @device = Device.find(params[:id])
    end

    def device_params
      params.require(:device).permit(
        :name, :serial_number, :asset_tag, :device_type,
        :status, :notes, :department_id, :employee_id
        # Note: ip_address_id is NOT permitted here, handled manually
      )
    end
end
