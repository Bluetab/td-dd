defmodule TdCx.Repo do
  use Ecto.Repo,
    otp_app: :td_cx,
    adapter: Ecto.Adapters.Postgres
end
