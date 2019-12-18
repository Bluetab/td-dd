defmodule TdCx.Auth.Guardian do
  @moduledoc false
  use Guardian, otp_app: :td_cx

  alias Jason, as: JSON
  alias TdCx.Accounts.User

  def subject_for_token(resource, _claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    sub = JSON.encode!(resource)
    {:ok, sub}
  end

  def resource_from_claims(claims) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In `above subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    sub = JSON.decode!(claims["sub"])

    resource = %User{
      id: sub["id"],
      is_admin: sub["is_admin"],
      user_name: sub["user_name"],
      jti: claims["jti"]
    }

    {:ok, resource}
  end
end
