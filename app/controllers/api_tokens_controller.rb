class ApiTokensController < ApplicationController
  def create
    _, raw = ApiToken.issue!(user: Current.user, name: token_params[:name])
    flash[:api_token_secret] = raw
    redirect_to account_path, notice: "API token created. Copy it now — it won't be shown again."
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy!
    redirect_to account_path, notice: "API token revoked."
  end

  private

  def token_params
    params.require(:api_token).permit(:name)
  end
end
