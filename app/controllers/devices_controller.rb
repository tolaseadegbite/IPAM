class DevicesController < ApplicationController
  before_action :set_device, only: %i[ show edit update destroy ]
  before_action :require_admin, only: [ :destroy ]

  def index
    records = Device.includes(:employee, :ip_addresses, department: :branch).order(:name)
    @search = records.ransack(params[:q])
    @pagy, @devices = pagy(@search.result)
  end

  def show
    # Fetch history efficiently
    @cards = @device.cards.includes(:list, :users).order(created_at: :desc)
  end

  def new
    @device = Device.new
    @device.department_id = params[:department_id] if params[:department_id].present?
  end

  def edit
    store_update_origin
  end

  def edit_status
    @device = Device.find(params[:id])
    # Renders app/views/devices/edit_status.html.erb automatically
  end

  def create
    @device = Device.new(device_params)

    if @device.save
      # NEW: Any IPs linked during creation must become active
      if @device.ip_address_ids.any?
        IpAddress.where(id: @device.ip_address_ids).update_all(status: :active)
      end

      respond_to do |format|
        format.html { redirect_to device_path(@device), notice: "Device registered." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              turbo_stream.prepend("devices-list", partial: "devices/device", locals: { device: @device }),
              turbo_stream.prepend(helpers.dom_id(@device.department, :devices), partial: "departments/device_show_card", locals: { device: @device }),
              turbo_stream.remove("no_devices_message"),
              turbo_stream.update("new_device", ""),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Device registered." })
            ]
          else
            redirect_to device_path(@device), notice: "Device registered.", status: :see_other
          end
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # 1. Clean the incoming array (removes the "" blank string) and convert to integers
    new_ip_ids = Array(device_params[:ip_address_ids]).reject(&:blank?).map(&:to_i)

    # 2. Get the current IDs before the update happens
    current_ip_ids = @device.ip_address_ids

    # 3. Figure out the differences
    ips_to_release = current_ip_ids - new_ip_ids
    ips_to_activate = new_ip_ids - current_ip_ids

    if @device.update(device_params)

      # NOTE: status flips use update_all deliberately — the device update
      # itself is versioned, and per-IP versions for bulk flips would spam
      # the audit log. IP transitions remain visible via device history.
      if ips_to_release.any?
        IpAddress.where(id: ips_to_release).update_all(status: :available)
      end

      if ips_to_activate.any?
        IpAddress.where(id: ips_to_activate).update_all(status: :active)
      end

      destination = stored_update_origin || device_path(@device)

      respond_to do |format|
        format.html { redirect_to destination, notice: "Device updated successfully." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              turbo_stream.replace(@device, partial: "devices/device", locals: { device: @device }),
              turbo_stream.update("name_and_serial", partial: "devices/name_and_serial"),
              turbo_stream.update("hardware_details", partial: "devices/hardware_details"),
              turbo_stream.update("network_and_owner_cards", partial: "devices/network_and_owner_cards"),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Device updated." })
            ]
          else
            redirect_to destination, notice: "Device updated successfully.", status: :see_other
          end
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Dependent :nullify in model handles IP release
    if @device.destroy
      respond_to do |format|
        format.html { redirect_to devices_path, notice: "Device deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(@device),
            turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Device deleted." })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to devices_path, alert: @device.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals: { alert: @device.errors.full_messages.to_sentence })
        end
      end
    end
  end

  def select_options
    @devices = Device.where(department_id: params[:department_id]).order(:name)
    # We render a partial that contains just the <option> tags or the whole select
    if (frame_id = request.headers["Turbo-Frame"].presence)
      render turbo_stream: turbo_stream.update(frame_id, partial: "devices/select_options", locals: { devices: @devices })
    else
      render partial: "devices/select_options", locals: { devices: @devices }
    end
  end

  private

  # The edit form POSTs from its own URL, so the Referer header can never
  # identify the originating page. Remember it on GET edit instead, as a
  # path (never a full URL) so foreign hosts can't sneak in.
  def store_update_origin
    referer = request.referer
    return if referer.blank?

    uri = URI.parse(referer)
    session[:device_return_to] = uri.request_uri if uri.host == request.host
  rescue URI::InvalidURIError
    nil
  end

  def stored_update_origin
    session.delete(:device_return_to).presence
  end

  def set_device
    @device = Device.find(params[:id])
  end

  def device_params
    params.require(:device).permit(
      :name, :device_type,
      :status, :mac_address, :critical, :location, :notes,
      :department_id, :employee_id, ip_address_ids: []
    )
  end
end
