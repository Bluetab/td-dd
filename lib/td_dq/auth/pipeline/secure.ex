defmodule TdDq.Auth.Pipeline.Secure do
 @moduledoc false

  use Guardian.Plug.Pipeline,
    otp_app: :td_dd,
    error_handler: TdDq.Auth.ErrorHandler,
    module: TdDq.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated
  plug TdDq.Auth.Plug.CurrentResource
end
