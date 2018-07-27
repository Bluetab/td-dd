defmodule TdDd.Accounts.User do
  @moduledoc false
  defstruct id: 0, user_name: nil, password: nil, is_admin: false, jti: nil

  def gen_id_from_user_name(user_name) do
    Integer.mod(:binary.decode_unsigned(user_name), 100_000)
  end

end
