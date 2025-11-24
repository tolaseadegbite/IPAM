class BranchesController < DashboardsController
  before_action :set_branch, only: %i[ show edit update destroy ]

  def index
    @branches = Branch.order(:name)
  end

  def show
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
          render turbo_stream: [
            turbo_stream.prepend("branches", partial: "branches/branch", locals: { branch: @branch }),
            turbo_stream.update("new_branch", ""), # Clear the form/modal
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Branch created successfully." })
          ]
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
          render turbo_stream: [
            turbo_stream.replace(@branch, partial: "branches/branch", locals: { branch: @branch }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Branch updated successfully." })
          ]
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
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Branch deleted." })
          ]
        end
      end
    else
      # If deletion fails (e.g., has departments), show error
      respond_to do |format|
        format.html { redirect_to branches_path, alert: @branch.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: @branch.errors.full_messages.to_sentence })
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