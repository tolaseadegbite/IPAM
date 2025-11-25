class DevicesController < ApplicationController
  before_action :set_device, only: %i[ show edit update destroy ]

  def index
    @devices = Device.includes(:department, :employee, :ip_address).order(:serial_number)

    if params[:query].present?
      term = "%#{params[:query]}%"
      @devices = @devices.where("name ILIKE ? OR serial_number ILIKE ? OR asset_tag ILIKE ?", term, term, term)
    end
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
              turbo_stream.prepend("devices", partial: "devices/device", locals: { device: @device }),
              turbo_stream.update("new_device", ""),
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
          format.html { redirect_to devices_path, notice: "Device updated." }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(@device, partial: "devices/device", locals: { device: @device }),
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
    respond_to do |format|
      format.html { redirect_to devices_path, notice: "Device retired." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@device),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Device retired." })
        ]
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