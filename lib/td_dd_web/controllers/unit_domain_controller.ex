defmodule TdDdWeb.UnitDomainController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Lineage.Units

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.unit_swagger_definitions()
  end

  swagger_path :index do
    description("List Unit domains")

    parameters do
      actions(:query, :string, "List of actions the user must be able to run over the domains",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:UnitDomainsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]
    domains = Units.list_domains()

    case get_actions(params) do
      [] ->
        domains = Enum.filter(domains, &can?(claims, view_domain(&1)))
        render(conn, "index.json", unit_domains: domains)

      actions ->
        filtered_domains = filter_domains(claims, domains, actions, params)
        render(conn, "index.json", unit_domains: filtered_domains)
    end
  end

  defp filter_domains(claims, domains, actions, %{"filter" => "all"}) do
    Enum.filter(domains, &can_all?(actions, claims, &1))
  end

  defp filter_domains(claims, domains, actions, _params) do
    Enum.filter(domains, &can_any?(actions, claims, &1))
  end

  defp can_all?(actions, claims, domain) do
    alias Canada.Can

    actions
    |> Enum.map(&String.to_atom/1)
    |> Enum.all?(&Can.can?(claims, &1, domain))
  end

  defp can_any?(actions, claims, domain) do
    alias Canada.Can

    actions
    |> Enum.map(&String.to_atom/1)
    |> Enum.any?(&Can.can?(claims, &1, domain))
  end

  defp get_actions(params) do
    params
    |> Map.get("actions", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
