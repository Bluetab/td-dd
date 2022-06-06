defmodule TdDqWeb.ImplementationController do
  use TdDqWeb, :controller
  use TdHypermedia, :controller

  import Canada, only: [can?: 2]
  import Canada.Can, only: [can?: 3]

  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Download
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.Search
  alias TdDq.Rules
  alias TdDq.Rules.RuleResults

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.implementation_definitions()
  end

  swagger_path :index do
    description("List Quality Rules")
    response(200, "OK", Schema.ref(:ImplementationsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    filters =
      %{}
      |> add_rule_filter(params, "rule_business_concept_id", "business_concept_id")
      |> add_rule_filter(params, "is_rule_active", "active")

    with {:can, true} <- {:can, can?(claims, list(Implementation))} do
      implementations =
        filters
        |> Implementations.list_implementations(preload: [:rule, :results], enrich: :source)
        |> Enum.map(&Implementations.enrich_implementation_structures/1)

      render(conn, "index.json", implementations: implementations)
    end
  end

  defp add_rule_filter(filters, params, param_name, filter_name) do
    case Map.get(params, param_name) do
      nil ->
        filters

      value ->
        rule_filters =
          filters
          |> Map.get("rule", %{})
          |> put_param_into_rule_filter(filter_name, value)

        Map.put(filters, "rule", rule_filters)
    end
  end

  defp put_param_into_rule_filter(filters, "active" = filter_name, value)
       when not is_boolean(value) do
    Map.put(filters, filter_name, value |> String.downcase() |> retrieve_boolean_value)
  end

  defp put_param_into_rule_filter(filters, filter_name, value),
    do: Map.put(filters, filter_name, value)

  defp retrieve_boolean_value("true"), do: true
  defp retrieve_boolean_value("false"), do: false
  defp retrieve_boolean_value(_), do: false

  swagger_path :create do
    description("Creates a Rule Implementation")
    produces("application/json")

    parameters do
      rule_implementation(
        :body,
        Schema.ref(:ImplementationCreate),
        "Rule Implementation creation parameters"
      )
    end

    response(201, "Created", Schema.ref(:ImplementationResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule_implementation" => %{"rule_id" => rule_id} = params}) do
    claims = conn.assigns[:current_resource]

    rule = Rules.get_rule_or_nil(rule_id)

    with {:ok, %{implementation: %{id: id}}} <-
           Implementations.create_implementation(rule, params, claims),
         implementation <-
           Implementations.get_implementation!(id, enrich: :source, preload: [:rule, :results]) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.implementation_path(conn, :show, implementation))
      |> render("show.json", implementation: implementation)
    end
  end

  def create(conn, %{"rule_implementation" => params}) do
    claims = conn.assigns[:current_resource]

    with {:ok, %{implementation: %{id: id}}} <-
           Implementations.create_ruleless_implementation(params, claims),
         implementation <-
           Implementations.get_implementation!(id, enrich: :source, preload: [:results]) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.implementation_path(conn, :show, implementation))
      |> render("show.json", implementation: implementation)
    end
  end

  swagger_path :show do
    description("Show Quality Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:ImplementationResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    implementation =
      id
      ## TODO: take this functionality with results context to add has_segments
      |> Implementations.get_implementation!(
        enrich: [:source, :links, :domain],
        preload: [
          :rule,
          [results: :remediation],
          [data_structures: [data_structure: [:system, :current_version]]]
        ]
      )
      |> add_last_rule_result()
      |> with_has_segments()
      |> add_quality_event()
      |> Implementations.enrich_implementation_structures()
      |> filter_links_by_permission(claims)
      |> filter_data_structures_by_permission(claims)

    actions = build_actions(claims, implementation)

    with {:can, true} <- {:can, can?(claims, show(implementation))} do
      render(conn, "show.json", implementation: implementation, actions: actions)
    end
  end

  defp filter_links_by_permission(implementation, %{role: "admin"}), do: implementation

  defp filter_links_by_permission(%{links: [_ | _] = links} = implementation, claims) do
    links = Enum.filter(links, fn link -> filter_link_by_permission(claims, link) end)
    Map.put(implementation, :links, links)
  end

  defp filter_links_by_permission(implementation, _claims), do: implementation

  defp filter_link_by_permission(claims, %{resource_type: :concept, domain: %{id: domain_id}}) do
    can?(claims, view_published_concept(domain_id))
  end

  defp filter_link_by_permission(_claims, _), do: false

  defp build_actions(claims, implementation) do
    [
      :clone,
      :deprecate,
      :edit,
      :execute,
      :link_concept,
      :link_structure,
      :manage,
      :manage_segments,
      :move,
      :publish,
      :reject,
      :submit
    ]
    |> Enum.filter(&can?(claims, &1, implementation))
    |> Enum.reduce(%{}, &Map.put(&2, &1, %{method: "POST"}))
  end

  defp filter_data_structures_by_permission(implementation, %{role: "admin"}), do: implementation

  defp filter_data_structures_by_permission(
         %{data_structures: [_ | _] = data_structures} = implementation,
         claims
       ) do
    data_structures =
      Enum.filter(data_structures, fn %{data_structure: data_structure} ->
        can?(claims, show(data_structure))
      end)

    Map.put(implementation, :data_structures, data_structures)
  end

  defp filter_data_structures_by_permission(implementation, _claims), do: implementation

  swagger_path :update do
    description("Updates Quality Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:ImplementationUpdate), "Quality Rule update parameters")
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:ImplementationResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule_implementation" => implementation_params}) do
    claims = conn.assigns[:current_resource]

    update_params =
      implementation_params
      |> Map.delete("implementation_type")

    implementation = Implementations.get_implementation!(id)

    with {:can, true} <- {:can, can?(claims, edit(implementation))},
         {:ok, _} <- Implementations.update_implementation(implementation, update_params, claims),
         implementation <-
           Implementations.get_implementation!(id, enrich: :source, preload: [:rule, :results]) do
      render(conn, "show.json", implementation: implementation)
    end
  end

  swagger_path :delete do
    description("Delete Quality Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    implementation = Implementations.get_implementation!(id)

    with {:can, true} <- {:can, can?(claims, delete(implementation))},
         {:ok, %{implementation: _}} <-
           Implementations.delete_implementation(implementation, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :search_rule_implementations do
    description("List Quality Rules")

    parameters do
      rule_id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:ImplementationsResponse))
  end

  def search_rule_implementations(conn, %{"rule_id" => id} = params) do
    claims = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with {:can, true} <- {:can, can?(claims, list(Implementation))},
         implementations <- Search.search_by_rule_id(params, claims, rule_id, 0, 1000) do
      render(conn, "index.json", implementations: implementations)
    end
  end

  swagger_path :csv do
    description("Download CSV of implementations")
    produces("application/json")

    parameters do
      search(:body, Schema.ref(:ImplementationsSearchFilters), "Search query parameter")
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error while CSV download")
  end

  def csv(conn, params) do
    claims = conn.assigns[:current_resource]

    {header_labels, params} = Map.pop(params, "header_labels", %{})
    {content_labels, params} = Map.pop(params, "content_labels", %{})

    implementations = Search.search(params, claims)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"implementations.zip\"")
    |> send_resp(:ok, Download.to_csv(implementations, header_labels, content_labels))
  end

  defp add_last_rule_result(%Implementation{} = implementation) do
    implementation
    |> Map.put(
      :_last_rule_result_,
      RuleResults.get_latest_rule_result(implementation)
    )
  end

  defp add_quality_event(%{id: id} = implementation) do
    Map.put(implementation, :quality_event, QualityEvents.get_event_by_imp(id))
  end

  ## TODO: refactor this function with SQL sentence
  defp with_has_segments(%Implementation{results: results} = impl)
       when length(results) >= 1 do
    parent_ids =
      results
      |> Enum.map(fn %{id: id} -> id end)
      |> RuleResults.has_segments()

    results =
      results
      |> Enum.map(fn %{id: parent_id} = result ->
        Map.put(result, :has_segments, Enum.member?(parent_ids, parent_id))
      end)

    Map.put(impl, :results, results)
  end

  defp with_has_segments(implementation), do: implementation
end
