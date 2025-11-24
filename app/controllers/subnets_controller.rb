class SubnetsController < DashboardsController
  before_action :set_subnet, only: %i[ show edit update destroy ]

  def index
    @subnets = Subnet.all.order(:name)
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
      # Auto-populate logic (inline for now, ideally background job)
      populate_ips_for(@subnet)

      respond_to do |format|
        format.html { redirect_to subnets_path, notice: "Subnet created and IPs populated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("subnets", partial: "subnets/subnet", locals: { subnet: @subnet }),
            turbo_stream.update("new_subnet", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Subnet created and IPs populated." })
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
        format.html { redirect_to subnets_path, notice: "Subnet updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@subnet, partial: "subnets/subnet", locals: { subnet: @subnet }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Subnet updated." })
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
          turbo_stream.remove(@subnet),
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

    # Simplified Population Logic
    def populate_ips_for(subnet)
      range = IPAddr.new(subnet.network_address.to_s).to_range.to_a
      # Exclude Network (first) and Broadcast (last)
      range[1...-1].each do |ip|
        subnet.ip_addresses.create(address: ip.to_s, status: :available)
      end
    rescue IPAddr::InvalidAddressError
      # handled by model validation usually
    end
end