defmodule TdDD.Canary.Abilities do
  @moduledoc false
  alias TdDD.Accounts.User

  defimpl Canada.Can, for: User do

    #def can?(%User{}, _action, nil),  do: false

    # administrator is superpowerful
    def can?(%User{is_admin: true}, _action, _domain)  do
      true
    end

  end
end
