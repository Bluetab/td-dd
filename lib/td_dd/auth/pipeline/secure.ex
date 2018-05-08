defmodule TdDd.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_dd,
    error_handler: TdDd.Auth.ErrorHandler,
    module: TdDd.Auth.Guardian
  # If there is a session token, validate it
  #plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  # If there is an authorization header, validate it
  #plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  # Load the user if either of the verifications worked
  plug Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"}
end
