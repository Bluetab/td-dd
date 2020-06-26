defmodule TdDqWeb.ImplementationController do
  use TdDqWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]
  import TdDqWeb.RuleImplementationSupport, only: [decode: 1]

  alias Ecto.Changeset
  alias TdDq.Repo
  alias TdDq.Rules
  alias TdDq.Rules.Implementations
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.RuleResults
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
  alias TdDqWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.implementation_definitions()
  end

  swagger_path :index do
    description("List Quality Rules")
    response(200, "OK", Schema.ref(:ImplementationsResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_resource]

    filters =
      %{}
      |> add_rule_filter(params, "rule_business_concept_id", "business_concept_id")
      |> add_rule_filter(params, "is_rule_active", "active")

    with {:can, true} <- {:can, can?(user, index(Implementation))} do
      implementations =
        filters
        |> Implementations.list_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&Implementations.enrich_implementation_structures/1)
        |> Enum.map(&Implementations.enrich_system/1)

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
    user = conn.assigns[:current_resource]
    implementation_params = decode(implementation_params)
    rule_id = implementation_params["rule_id"]

    rule = Rules.get_rule_or_nil(rule_id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "implementation",
      "implementation_type" => Map.get(implementation_params, "implementation_type")
    }

    with {:can, true} <- {:can, can?(user, create(resource_type))},
         {:ok, %Implementation{} = implementation} <-
           Implementations.create_implementation(rule, implementation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", implementation_path(conn, :show, implementation))
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
      |> Implementations.get_implementation!()
      |> Repo.preload([:rule])
      |> add_rule_results()
      |> add_last_rule_result()
      |> Implementations.enrich_implementation_structures()
      |> Implementations.enrich_system()

    user = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(user, show(implementation))} do
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
    user = conn.assigns[:current_resource]

    update_params =
      implementation_params
      |> decode()
      |> Map.drop([
        :implementation_key,
        "implementation_key",
        :implementation_type,
        "implementation_type"
      ])

    implementation =
      id
      |> Implementations.get_implementation!()
      |> Repo.preload([:rule])
      |> add_rule_results()

    rule = implementation.rule

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "implementation",
      "implementation_type" => implementation.implementation_type
    }

    with {:can, true} <- {:can, can?(user, update(resource_type))},
         {:editable, true} <-
           {:editable,
            Enum.empty?(implementation.all_rule_results) ||
              (Map.keys(implementation_params) == ["soft_delete"] &&
                 Map.get(implementation_params, "soft_delete") == true)},
         {:ok, %Implementation{} = implementation} <-
          Implementations.update_implementation(
             implementation,
             with_soft_delete(update_params)
           ) do
      render(conn, "show.json", implementation: implementation)
    else
      {:can, false} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        Logger.error("While updating rule implementation... #{inspect(changeset)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.implementation.error"
        )

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.implementation.system_params.error"
        )

      error ->
        Logger.error("While updating rule implementation... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
    implementation = Implementations.get_implementation!(id)
    user = conn.assigns[:current_resource]
    rule = Repo.preload(implementation, :rule).rule

    with {:can, true} <-
           {:can,
            can?(
              user,
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
    user = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with {:can, true} <- {:can, can?(user, index(Implementation))} do
      opts = deleted_implementations(params)

      implementations =
        %{"rule_id" => rule_id}
        |> Implementations.list_implementations(opts)
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result/1)
        |> Enum.map(&Implementations.enrich_implementation_structures/1)
        |> Enum.map(&Implementations.enrich_system/1)

      render(conn, "index.json", implementations: implementations)
    end
  end

  swagger_path :search_rules_implementations do
    description("Searh rule implementations")

    parameters do
      search(
        :body,
        Schema.ref(:ImplementationsSearchFilters),
        "Filter by Rule, Rule Implementation or structure properties"
      )
    end

    produces("application/json")

    response(200, "OK", Schema.ref(:ImplementationsResponse))
  end

  # Endpoint used by DD to search structure implementations
  def search_rules_implementations(conn, %{"structure_id" => structure_id}) do
    user = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(user, index(Implementation))} do
      implementations =
        %{"structure_id" => String.to_integer(structure_id)}
        |> Implementations.list_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result(&1))

      render(conn, "index.json", implementations: implementations)
    end
  end

  # Endpoint for dq engine
  def search_rules_implementations(conn, filters) do
    filters = Map.get(filters, "filters", %{})
    user = conn.assigns[:current_resource]
    opts = deleted_implementations(filters)
    opts = Keyword.put(opts, :enrich_structures, true)

    with {:can, true} <- {:can, can?(user, index(Implementation))} do
      implementations =
        filters
        |> Implementations.list_implementations(opts)
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result(&1))

      render(conn, "index.json", implementations: implementations)
    end
  end

  defp add_last_rule_result(implementation) do
    implementation
    |> Map.put(
      :_last_rule_result_,
      RuleResults.get_latest_rule_result(implementation.implementation_key)
    )
  end

  defp add_rule_results(implementation) do
    implementation
    |> Map.put(
      :all_rule_results,
      RuleResults.get_implementation_results(implementation.implementation_key)
    )
  end

  defp deleted_implementations(%{"status" => "deleted"}), do: [deleted: true]

  defp deleted_implementations(_), do: []

  defp with_soft_delete(%{"soft_delete" => true} = params) do
    params
    |> Map.delete("soft_delete")
    |> Map.put("deleted_at", DateTime.utc_now())
  end

  defp with_soft_delete(params), do: params
end
