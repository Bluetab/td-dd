defmodule TdCx.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_cx,
    error_handler: TdCx.Auth.ErrorHandler,
    module: TdCx.Auth.Guardian
  # If there is a session token, validate it
  #plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  # If there is an authorization header, validate it
  #plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  # Load the user if either of the verifications worked
  plug Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"}

  # Assign :current_user to connection
  plug TdCx.Auth.CurrentUser

end
