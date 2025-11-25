class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[ show edit update destroy ]

  def index
    @departments = Department.includes(:branch).order("branches.name", :name)
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
        format.html { redirect_to departments_path, notice: "Department created." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("departments", partial: "departments/department", locals: { department: @department }),
            turbo_stream.update("new_department", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department created." })
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
        format.html { redirect_to departments_path, notice: "Department updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@department, partial: "departments/department", locals: { department: @department }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department updated." })
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @department.destroy
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department deleted." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(@department),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Department deleted." })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to departments_path, alert: "Cannot delete department with active employees/devices." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: "Cannot delete department with active employees/devices." })
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