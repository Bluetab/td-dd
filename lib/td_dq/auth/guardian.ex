defmodule TdDq.Auth.Guardian do
  @moduledoc "Guardian implementation module"

  use Guardian, otp_app: :td_dd

  alias TdDq.Auth.Claims

  def subject_for_token(%Claims{user_id: user_id, user_name: user_name}, _claims) do
    Jason.encode(%{id: user_id, user_name: user_name})
  end

  def resource_from_claims(%{"role" => role, "sub" => sub, "exp" => exp} = claims) do
    %{"id" => id, "user_name" => user_name} = Jason.decode!(sub)

    resource = %Claims{
      exp: exp,
      user_id: id,
      role: role,
      user_name: user_name,
      jti: claims["jti"]
    }

    {:ok, resource}
  end
end