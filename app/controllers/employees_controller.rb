class EmployeesController < ApplicationController
  before_action :set_employee, only: %i[ show edit update destroy ]

  def index
    records = Employee.includes(department: :branch).order(:last_name, :first_name)
    @search = records.ransack(params[:q])
    @pagy, @employees = pagy(@search.result)
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
        format.html { redirect_to employees_path, notice: "Employee created successfully." }
        format.turbo_stream do
          render turbo_stream: [
             turbo_stream.prepend("employees-table", partial: "employees/employee", locals: { employee: @employee }),
            turbo_stream.prepend("employees-cards", partial: "employees/employee_card", locals: { employee: @employee }),
            turbo_stream.update("new_employee", ""), # Clear the form/modal
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee created successfully." })
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
        format.html { redirect_to employees_path, notice: "Employee updated successfully." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@employee, :table_row), partial: "employees/employee", locals: { employee: @employee }),
            turbo_stream.replace(helpers.dom_id(@employee, :card), partial: "employees/employee_card", locals: { employee: @employee }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee updated successfully." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Constraint check handled by model (restrict_with_error)
    if @employee.destroy
      respond_to do |format|
        format.html { redirect_to employees_path, notice: "Employee deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(helpers.dom_id(@employee, :table_row)),
            turbo_stream.remove(helpers.dom_id(@employee, :card)),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Employee deleted." })
          ]
        end
      end
    else
      # If deletion fails (e.g., has departments), show error
      respond_to do |format|
        format.html { redirect_to employees_path, alert: @employee.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: @employee.errors.full_messages.to_sentence })
        end
      end
    end
  end

  private
    def set_employee
      @employee = Employee.find(params[:id])
    end

    def employee_params
      params.require(:employee).permit(:first_name, :last_name, :department_id, :status)
    end
end
