class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[ show edit update destroy ]

  def index
    records = Department.includes(:branch).order("branches.name", :name)
    @search = records.ransack(params[:q])
    @pagy, @departments = pagy(@search.result)
  end

  def show
  end

  def new
    @department = Department.new
  end

  def edit
  end

  def create
    @department = Department.new(department_params)

    if @department.save
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department created successfully." }
        format.turbo_stream do
          render turbo_stream: [
             turbo_stream.prepend("departments-table", partial: "departments/department", locals: { department: @department }),
            turbo_stream.prepend("departments-cards", partial: "departments/department_card", locals: { department: @department }),
            turbo_stream.update("new_department", ""), # Clear the form/modal
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department created successfully." })
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department updated successfully." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@department, :table_row), partial: "departments/department", locals: { department: @department }),
            turbo_stream.replace(helpers.dom_id(@department, :card), partial: "departments/department_card", locals: { department: @department }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department updated successfully." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Constraint check handled by model (restrict_with_error)
    if @department.destroy
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(helpers.dom_id(@department, :table_row)),
            turbo_stream.remove(helpers.dom_id(@department, :card)),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department deleted." })
          ]
        end
      end
    else
      # If deletion fails (e.g., has departments), show error
      respond_to do |format|
        format.html { redirect_to departments_path, alert: @department.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: @department.errors.full_messages.to_sentence })
        end
      end
    end
  end

  private
    def set_department
      @department = Department.find(params[:id])
    end

    def department_params
      params.require(:department).permit(:name, :branch_id)
    end
end
