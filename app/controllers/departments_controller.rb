class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[ show edit update destroy ]

  def index
    records = Department.includes(:branch).order("branches.name", :name)
    @search = records.ransack(params[:q])
    @pagy, @departments = pagy(@search.result)
  end

  def show
    # Members render on the branch page; show keeps header, details, audit.
  end

  def new
    @department = Department.new

    @department.branch_id = params[:branch_id] if params[:branch_id].present?
  end

  def edit
  end

  def create
    @department = Department.new(department_params)

    if @department.save
      respond_to do |format|
        format.html { redirect_to departments_path, notice: "Department created successfully." }
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
               turbo_stream.prepend("departments-list", partial: "departments/department", locals: { department: @department }),
              turbo_stream.append("departments_accordion", partial: "branches/department_section", locals: { department: @department, employees: [], devices: [] }),
              turbo_stream.update("new_department", ""), # Clear the form/modal
              turbo_stream.update("empty_state", ""), # Clear the empty state
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Department created successfully." })
            ]
          else
            redirect_to departments_path, notice: "Department created successfully.", status: :see_other
          end
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
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: [
              turbo_stream.replace(@department, partial: "departments/department", locals: { department: @department }),
              turbo_stream.update(("department_details"), partial: "departments/department_details", locals: { department: @department }),
              turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Department updated successfully." })
            ]
          else
            redirect_to departments_path, notice: "Department updated successfully.", status: :see_other
          end
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
            turbo_stream.remove(@department),
            turbo_stream.update("flash_messages", partial: "shared/flash", locals: { notice: "Department deleted." })
          ]
        end
      end
    else
      # If deletion fails (e.g., has departments), show error
      respond_to do |format|
        format.html { redirect_to departments_path, alert: @department.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals: { alert: @department.errors.full_messages.to_sentence })
        end
      end
    end
  end

  def select_options
    # Filter departments by the branch_id passed in params
    @departments = Department.where(branch_id: params[:branch_id]).order(:name)

    # We render a specific partial designed just for the select box.
    # Frame navigations (dependent selects) get a stream targeted at the
    # requesting frame; anything else gets the bare partial as before.
    if (frame_id = request.headers["Turbo-Frame"].presence)
      render turbo_stream: turbo_stream.update(frame_id, partial: "departments/select_options", locals: { departments: @departments })
    else
      render partial: "departments/select_options", locals: { departments: @departments }
    end
  end

  private
    def set_department
      @department = Department.includes(:branch).find(params[:id])
    end

    def department_params
      params.require(:department).permit(:name, :branch_id)
    end
end
