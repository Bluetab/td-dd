defmodule TdDqWeb.ImplementationController do
  use TdDqWeb, :controller
  use TdHypermedia, :controller

  import Canada, only: [can?: 2]
  import TdDqWeb.RuleImplementationSupport, only: [decode: 1]

  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Download
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.Search
  alias TdDq.Rules
  alias TdDq.Rules.RuleResults
  alias TdDqWeb.ErrorView

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

    with {:can, true} <- {:can, can?(claims, index(Implementation))} do
      implementations =
        filters
        |> Implementations.list_implementations(preload: :rule, enrich: :source)
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
    description("Creates a Quality Rule")
    produces("application/json")

    parameters do
      rule_implementation(
        :body,
        Schema.ref(:ImplementationCreate),
        "Quality Rule creation parameters"
      )
    end

    response(201, "Created", Schema.ref(:ImplementationResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule_implementation" => implementation_params}) do
    claims = conn.assigns[:current_resource]
    implementation_params = decode(implementation_params)
    rule_id = implementation_params["rule_id"]

    rule = Rules.get_rule_or_nil(rule_id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "implementation",
      "implementation_type" => Map.get(implementation_params, "implementation_type")
    }

    with {:can, true} <- {:can, can?(claims, create(resource_type))},
         {:ok, %Implementation{} = implementation} <-
           Implementations.create_implementation(rule, implementation_params) do
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
    implementation =
      id
      |> Implementations.get_implementation!(preload: :rule, enrich: :source)
      |> add_rule_results()
      |> add_last_rule_result()
      |> add_quality_event()
      |> Implementations.enrich_implementation_structures()

    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, show(implementation))} do
      render(conn, "show.json", implementation: implementation)
    end
  end

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
      |> decode()
      |> Map.drop([:implementation_type, "implementation_type"])
      |> with_deleted_at()

    implementation =
      id
      |> Implementations.get_implementation!(preload: :rule)
      |> add_rule_results()

    rule = implementation.rule

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "implementation",
      "implementation_type" => implementation.implementation_type
    }

    # TODO: Refactor this (and remove {:editable, false} from fallback controller)
    with {:can, true} <- {:can, can?(claims, update(resource_type))},
         {:editable, true} <- {:editable, editable?(implementation, implementation_params)},
         {:ok, %{implementation: %Implementation{} = implementation}} <-
           Implementations.update_implementation(implementation, update_params, claims) do
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
    %{rule: rule} = implementation = Implementations.get_implementation!(id, preload: :rule)
    claims = conn.assigns[:current_resource]

    with {:can, true} <-
           {:can,
            can?(
              claims,
              delete(%{
                "business_concept_id" => rule.business_concept_id,
                "resource_type" => "implementation",
                "implementation_type" => implementation.implementation_type
              })
            )},
         {:ok, %Implementation{}} <- Implementations.delete_implementation(implementation) do
      send_resp(conn, :no_content, "")
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
    IO.puts("SEARCH_RULE_IMPLEMENTATIONS")
    claims = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with {:can, true} <- {:can, can?(claims, index(Implementation))},
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

  defp add_last_rule_result(implementation) do
    implementation
    |> Map.put(
      :_last_rule_result_,
      RuleResults.get_latest_rule_result(implementation.implementation_key)
    )
  end

  defp add_rule_results(implementation) do
    Map.put(
      implementation,
      :all_rule_results,
      RuleResults.get_implementation_results(implementation.implementation_key)
    )
  end

  defp add_quality_event(%{id: id} = implementation) do
    Map.put(implementation, :quality_event, QualityEvents.get_event_by_imp(id))
  end

  defp editable?(%{all_rule_results: []}, _params), do: true
  defp editable?(_implementation, %{"soft_delete" => true}), do: true
  defp editable?(_implementation, %{"restore" => true}), do: true
  defp editable?(_implementation, _parmas), do: false

  defp with_deleted_at(params) do
    case params do
      %{"soft_delete" => true} ->
        params
        |> Map.delete("soft_delete")
        |> Map.put("deleted_at", DateTime.utc_now())

      %{"restore" => true} ->
        params
        |> Map.delete("restore")
        |> Map.put("deleted_at", nil)

      _ ->
        params
    end
  end
end
