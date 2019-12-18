defmodule TdCx.Accounts.Group do
  @moduledoc false
  defstruct id: 0, name: nil

  def gen_id_from_name(name) do
    Integer.mod(:binary.decode_unsigned(name), 100_000)
  end
end
