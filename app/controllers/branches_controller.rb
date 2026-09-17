class BranchesController < ApplicationController
  before_action :set_branch, only: %i[ show edit update destroy ]

  def index
    records = Branch.order(:name)
    @search = records.ransack(params[:q])
    @pagy, @branches = pagy(@search.result)
  end

  def show
    @departments = @branch.departments.order(:name)
    # Whole hierarchy in three queries for the collapsible tree below.
    @employees_by_department = Employee.where(department: @departments).order(:first_name).group_by(&:department_id)
    @devices_by_department = Device.where(department: @departments).includes(:employee).order(:name).group_by(&:department_id)
    @subnets = @branch.subnets.order(:name)
    @subnet_usage = IpAddress.where(subnet: @subnets).group(:subnet_id, :status).count
  end

  def new
    @branch = Branch.new
  end

  def edit
  end

  def create
    @branch = Branch.new(branch_params)

    if @branch.save
      respond_to do |format|
        format.html { redirect_to branches_path, notice: "Branch created successfully." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
               turbo_stream.prepend("branches-list", partial: "branches/branch", locals: { branch: @branch }),
              turbo_stream.update("new_branch", ""), # Clear the form/modal
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Branch created successfully." })
            ]
          else
            redirect_to branches_path, notice: "Branch created successfully.", status: :see_other
          end
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @branch.update(branch_params)
      respond_to do |format|
        format.html { redirect_to branches_path, notice: "Branch updated successfully." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              turbo_stream.replace(@branch, partial: "branches/branch", locals: { branch: @branch }),
              turbo_stream.update(("branch_name"), partial: "branches/branch_name", locals: { branch: @branch }),
              turbo_stream.update(("branch_details"), partial: "branches/details", locals: { branch: @branch }),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Branch updated successfully." })
            ]
          else
            redirect_to branches_path, notice: "Branch updated successfully.", status: :see_other
          end
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Constraint check handled by model (restrict_with_error)
    if @branch.destroy
      respond_to do |format|
        format.html { redirect_to branches_path, notice: "Branch deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(@branch),
            turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Branch deleted." })
          ]
        end
      end
    else
      # If deletion fails (e.g., has departments), show error
      respond_to do |format|
        format.html { redirect_to branches_path, alert: @branch.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals: { alert: @branch.errors.full_messages.to_sentence })
        end
      end
    end
  end

  private
    def set_branch
      @branch = Branch.find(params[:id])
    end

    def branch_params
      params.require(:branch).permit(:name, :location, :contact_phone)
    end
end
