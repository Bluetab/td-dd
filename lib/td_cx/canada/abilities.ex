defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Auth.Claims
  alias TdCx.Canada.SourceAbilities
  alias TdCx.Configurations.Configuration
  alias TdCx.Jobs.Job
  alias TdCx.Permissions
  alias TdCx.Sources.Source

  defimpl Canada.Can, for: Claims do
    def can?(%Claims{role: role, user_name: user_name}, :view_secrets, %Source{type: type})
        when role in ["admin", "service"] do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{role: role, user_name: user_name}, :view_secrets, %Configuration{type: type})
        when role in ["admin", "service"] do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{role: role, user_name: user_name}, :view_secrets, %{"type" => type})
        when role in ["admin", "service"] do
      String.downcase(type) == String.downcase(user_name)
    end

    def can?(%Claims{}, :view_secrets, %{"type" => _}), do: false
    def can?(%Claims{}, :view_secrets, %Source{}), do: false
    def can?(%Claims{}, :view_secrets, %Configuration{}), do: false
    def can?(%Claims{role: role}, _action, _domain) when role in ["admin", "service"], do: true

    def can?(%Claims{role: "user"} = claims, action, Job) when action in [:show, :create] do
      Permissions.has_permission?(claims, :profile_structures)
    end

    def can?(%Claims{role: "user"} = claims, :list, Source) do
      SourceAbilities.can?(claims, :list, Source)
    end

    def can?(%Claims{}, _action, _domain), do: false
  end
end
