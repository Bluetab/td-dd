defmodule TdDq.Accounts.User do
  @moduledoc false

  @derive Jason.Encoder
  defstruct id: 0, user_name: nil, is_admin: false, jti: nil
end
