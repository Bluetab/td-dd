defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Accounts.User

  defimpl Canada.Can, for: User do
    def can?(%User{is_admin: true}, _action, _domain), do: true

    def can?(%User{}, _action, _domain), do: false
  end
end
