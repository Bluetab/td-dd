defmodule TdDd.Auth.Pipeline.Secure do
  @moduledoc false

  use Guardian.Plug.Pipeline,
    otp_app: :td_dd,
    error_handler: TdDd.Auth.ErrorHandler,
    module: TdDd.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"}
  plug TdDd.Auth.CurrentResource
end
