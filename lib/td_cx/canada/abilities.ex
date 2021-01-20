defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Auth.Claims
  alias TdCx.Sources.Source

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{role: role, user_name: user_name}, :view_secrets, %Source{type: type})
        when role in ["admin", "service"] do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{role: role, user_name: user_name}, :view_secrets, %{"type" => type})
        when role in ["admin", "service"] do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{}, :view_secrets, %{"type" => _}), do: false
    def can?(%Claims{}, :view_secrets, %Source{}), do: false
    def can?(%Claims{role: role}, _action, _domain) when role in ["admin", "service"], do: true
    def can?(%Claims{}, _action, _domain), do: false
  end
end
