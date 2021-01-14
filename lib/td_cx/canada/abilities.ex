defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Auth.Claims
  alias TdCx.Sources.Source

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{is_admin: true, user_name: user_name}, :view_secrets, %Source{type: type}) do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{is_admin: true, user_name: user_name}, :view_secrets, %{"type" => type}) do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{}, :view_secrets, %{"type" => _type}) do
      false
    end

    def can?(%Claims{}, :view_secrets, %Source{}) do
      false
    end

    def can?(%Claims{is_admin: true}, _action, _domain), do: true

    def can?(%Claims{}, _action, _domain), do: false
  end
end
