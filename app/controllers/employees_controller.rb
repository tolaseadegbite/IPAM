class EmployeesController < DashboardsController
  before_action :set_employee, only: %i[ show edit update destroy ]

  def index
    @employees = Employee.includes(department: :branch).order(:last_name, :first_name)
    
    if params[:query].present?
      @employees = @employees.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                                    "%#{params[:query]}%", "%#{params[:query]}%", "%#{params[:query]}%")
    end
  end

  def show
  end

  def new
    @employee = Employee.new
  end

  def edit
  end

  def create
    @employee = Employee.new(employee_params)

    if @employee.save
      respond_to do |format|
        format.html { redirect_to employees_path, notice: "Employee onboarded." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("employees", partial: "employees/employee", locals: { employee: @employee }),
            turbo_stream.update("new_employee", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee onboarded." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @employee.update(employee_params)
      respond_to do |format|
        format.html { redirect_to employees_path, notice: "Employee updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@employee, partial: "employees/employee", locals: { employee: @employee }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee updated." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy
    respond_to do |format|
      format.html { redirect_to employees_path, notice: "Employee record removed." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@employee),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee record removed." })
        ]
      end
    end
  end

  private
    def set_employee
      @employee = Employee.find(params[:id])
    end

    def employee_params
      params.require(:employee).permit(:first_name, :last_name, :email, :department_id, :status)
    end
end