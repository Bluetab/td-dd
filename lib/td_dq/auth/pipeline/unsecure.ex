defmodule TdDq.Auth.Pipeline.Unsecure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_dq,
    error_handler: TdDq.Auth.ErrorHandler,
    module: TdDq.Auth.Guardian

  plug Guardian.Plug.VerifyHeader
  plug Guardian.Plug.LoadResource, allow_blank: true
end
