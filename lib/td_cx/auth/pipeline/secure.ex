defmodule TdCx.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_cx,
    error_handler: TdCx.Auth.ErrorHandler,
    module: TdCx.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"}
  plug TdCx.Auth.CurrentResource
end
