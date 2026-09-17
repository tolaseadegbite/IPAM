class SubnetsController < ApplicationController
  before_action :set_subnet, only: %i[ show edit update destroy ]
  before_action :require_admin, only: [ :destroy ]

  def index
    records = Subnet.all.order(:name)
    @search = records.ransack(params[:q])
    @pagy, @subnets = pagy(@search.result)
  end

  def show
    pool = @subnet.ip_addresses.includes(:device).order(:address)
    pool = pool.where.not(device_id: nil) if params[:pool] == "assigned"
    pool = pool.free if params[:pool] == "free"
    if params[:addr].present?
      query = "%#{params[:addr].gsub(/[%_]/, "")}%"
      pool = pool.where("host(address) ILIKE ?", query)
    end
    @pagy, @pool_ips = pagy(pool, limit: 96)

    # Impact statement for the delete dialog: assigned IPs evaporate with
    # the subnet while their devices survive untouched.
    assigned = @subnet.ip_addresses.where.not(device_id: nil)
    @assigned_ip_count = assigned.count
    assigned_device_ids = assigned.distinct.pluck(:device_id)
    @assigned_devices = Device.where(id: assigned_device_ids.first(5)).order(:name).pluck(:name)
    @assigned_device_overflow = [ assigned_device_ids.size - @assigned_devices.size, 0 ].max
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
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
               turbo_stream.prepend("subnets-list", partial: "subnets/subnet", locals: { subnet: @subnet }),
              turbo_stream.update("new_subnet", ""), # Clear the form/modal
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Subnet created successfully." })
            ]
          else
            redirect_to subnets_path, notice: "Subnet created successfully.", status: :see_other
          end
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
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              turbo_stream.replace(@subnet, partial: "subnets/subnet", locals: { subnet: @subnet }),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Subnet updated successfully." })
            ]
          else
            redirect_to subnets_path, notice: "Subnet updated successfully.", status: :see_other
          end
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
          turbo_stream.remove(@subnet),
          turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Subnet deleted." })
        ]
      end
    end
  end

  private
    def set_subnet
      @subnet = Subnet.find(params[:id])
    end

    def subnet_params
      params.require(:subnet).permit(:name, :network_address, :gateway, :vlan_id, :branch_id)
    end
end
