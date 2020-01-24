defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Accounts.User
  alias TdCx.Sources.Source

  defimpl Canada.Can, for: User do
    def can?(%User{is_admin: true, user_name: user_name}, :view_secrets, %Source{type: type}) do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%User{is_admin: true, user_name: user_name}, :view_secrets, %{"type" => type}) do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%User{}, :view_secrets, %{"type" => _type}) do
      false
    end

    def can?(%User{}, :view_secrets, %Source{}) do
      false
    end

    def can?(%User{is_admin: true}, _action, _domain), do: true

    def can?(%User{}, _action, _domain), do: false
  end
end
