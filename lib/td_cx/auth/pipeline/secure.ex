defmodule TdCx.Auth.Pipeline.Secure do
  @moduledoc """
  Plug pipeline for routes requiring authentication
  """

  use Guardian.Plug.Pipeline,
    otp_app: :td_cx,
    error_handler: Truedat.Auth.ErrorHandler,
    module: TdCx.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated, claims: %{"aud" => "truedat", "iss" => "tdauth"}
  plug Guardian.Plug.LoadResource
  plug Truedat.Auth.Plug.SessionExists
  plug Truedat.Auth.Plug.CurrentResource
end
