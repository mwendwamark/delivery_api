# app/controllers/api/users_controller.rb
module Api
  class UsersController < ApplicationController
    before_action :authenticate_request
    before_action :require_admin
    before_action :set_user, only: [:show, :update, :destroy]
    
    USERS_PER_PAGE = 20
    
    def index
      users = User.all.order(created_at: :desc)
      
      # Apply filters
      users = filter_by_role(users) if params[:role].present?
      users = search_users(users) if params[:search].present?
      
      # Get total count before pagination
      total_count = users.count
      
      # Manual pagination
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || USERS_PER_PAGE).to_i
      offset = (page - 1) * per_page
      
      paginated_users = users.limit(per_page).offset(offset)
      total_pages = (total_count.to_f / per_page).ceil
      
      render json: {
        users: paginated_users.as_json(
          only: [:id, :email, :first_name, :last_name, :phone_number, :role, :created_at, :date_of_birth],
          methods: [:age_verified?]
        ),
        meta: {
          current_page: page,
          next_page: page < total_pages ? page + 1 : nil,
          prev_page: page > 1 ? page - 1 : nil,
          total_pages: total_pages,
          total_count: total_count
        }
      }
    end
    
    def show
      render json: {
        user: @user.as_json(
          only: [:id, :email, :first_name, :last_name, :phone_number, :role, :created_at, :date_of_birth],
          methods: [:age_verified?],
          include: {
            addresses: { only: [:id, :location, :street_address] },
            orders: { only: [:id, :status, :total_price, :created_at] }
          }
        )
      }
    end
    
    def update
      if @user.update(user_update_params)
        render json: {
          message: 'User updated successfully',
          user: @user.as_json(only: [:id, :email, :first_name, :last_name, :phone_number, :role])
        }
      else
        render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
      end
    end
    
    def destroy
      @user.destroy
      render json: { message: 'User deleted successfully' }
    end
    
    private
    
    def set_user
      @user = User.find_by(id: params[:id])
      render json: { error: 'User not found' }, status: :not_found unless @user
    end
    
    def require_admin
      unless current_user&.admin?
        render json: { error: 'Admin access required' }, status: :forbidden
      end
    end
    
    def filter_by_role(users)
      role_value = params[:role].to_i
      users.where(role: role_value)
    end
    
    def search_users(users)
      search_term = "%#{params[:search]}%"
      users.where(
        "email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ? OR phone_number ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end
    
    def user_update_params
      params.require(:user).permit(:first_name, :last_name, :phone_number, :role)
    end
  end
end