defmodule TdCx.Canada.Abilities do
  @moduledoc false
  alias TdCx.Auth.Claims
  alias TdCx.Jobs.Job
  alias TdCx.Permissions
  alias TdCx.Sources.Source
  alias TdCx.Taxonomies.Domain

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

    def can?(%Claims{role: "user"} = claims, action, Job) when action in [:show, :create] do
      Permissions.has_any_permission_on_resource_type?(claims, [:profile_structures], Domain)
    end

    def can?(%Claims{role: "user"} = claims, :list, Source) do
      Permissions.has_any_permission_on_resource_type?(claims, [:manage_raw_quality_rule_implementations], Domain)
    end

    def can?(%Claims{}, _action, _domain), do: false
  end
end
