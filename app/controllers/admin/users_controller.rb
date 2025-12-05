module Admin
  class UsersController < ApplicationController
    before_action :require_admin
    before_action :set_user, only: %i[ edit update destroy ]

    def index
      # Sort by created_at by default, allow Ransack search
      @search = User.order(created_at: :desc).ransack(params[:q])
      @pagy, @users = pagy(@search.result)
    end

    def new
      @user = User.new
    end

    def edit
    end

    def create
      @user = User.new(user_params)

      if @user.save
        respond_to do |format|
          format.html { redirect_to admin_users_path, notice: "User created successfully." }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend("users-table", partial: "admin/users/user_row", locals: { user: @user }),
              turbo_stream.prepend("users-cards", partial: "admin/users/user_card", locals: { user: @user }),
              turbo_stream.update("new_user", ""), # Clear modal/form
              turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "User created successfully." })
            ]
          end
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      # Remove password params if left blank (so we don't reset it to empty string)
      if params[:user][:password].blank?
        params[:user].delete(:password)
      end

      if @user.update(user_params)
        respond_to do |format|
          format.html { redirect_to admin_users_path, notice: "User updated successfully." }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@user, :table_row), partial: "admin/users/user_row", locals: { user: @user }),
              turbo_stream.replace(helpers.dom_id(@user, :card), partial: "admin/users/user_card", locals: { user: @user }),
              turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "User updated successfully." })
            ]
          end
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == Current.user
        flash.now[:alert] = "You cannot delete your own account."
        render_error_stream
        return
      end

      if @user.destroy
        respond_to do |format|
          format.html { redirect_to admin_users_path, notice: "User deleted." }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@user, :table_row)),
              turbo_stream.remove(helpers.dom_id(@user, :card)),
              turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "User deleted." })
            ]
          end
        end
      else
        flash.now[:alert] = "Could not delete user."
        render_error_stream
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:username, :email, :password, :admin, :verified)
    end

    def render_error_stream
      respond_to do |format|
        format.html { redirect_to admin_users_path, alert: flash[:alert] }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { alert: flash[:alert] })
        end
      end
    end
  end
end
