defmodule TdDqWeb.RuleImplementationController do
  use TdDqWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]
  import TdDqWeb.RuleImplementationSupport, only: [decode: 1]

  alias Ecto.Changeset
  alias TdDq.Repo
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
  alias TdDqWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.rule_implementation_definitions()
  end

  swagger_path :index do
    description("List Quality Rules")
    response(200, "OK", Schema.ref(:RuleImplementationsResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_resource]

    filters =
      %{}
      |> add_rule_filter(params, "rule_business_concept_id", "business_concept_id")
      |> add_rule_filter(params, "is_rule_active", "active")

    with {:can, true} <- {:can, can?(user, index(RuleImplementation))} do
      rule_implementations =
        filters
        |> Rules.list_rule_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&Rules.enrich_rule_implementation_structures(&1))
        |> Enum.map(&Rules.enrich_system(&1))

      render(conn, "index.json", rule_implementations: rule_implementations)
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
        Schema.ref(:RuleImplementationCreate),
        "Quality Rule creation parameters"
      )
    end

    response(201, "Created", Schema.ref(:RuleImplementationResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule_implementation" => rule_implementation_params}) do
    user = conn.assigns[:current_resource]
    rule_implementation_params = decode(rule_implementation_params)
    rule_id = rule_implementation_params["rule_id"]

    rule = Rules.get_rule_or_nil(rule_id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule_implementation",
      "implementation_type" => Map.get(rule_implementation_params, "implementation_type")
    }

    with {:can, true} <- {:can, can?(user, create(resource_type))},
         {:valid_implementation_key} <-
           check_valid_implementation_key(rule_implementation_params),
         {:implementation_key_available} <-
           Rules.check_available_implementation_key(rule_implementation_params),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.create_rule_implementation(rule, rule_implementation_params),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           generate_implementation_key(rule_implementation, rule) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_implementation_path(conn, :show, rule_implementation))
      |> render("show.json", rule_implementation: rule_implementation)
    else
      {:can, false} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:invalid_implementation_key} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: [
            %{code: "EDQ001", name: "rule.implementation.error.implementation_key.invalid"}
          ]
        })

      {:implementation_key_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: [
            %{code: "EDQ002", name: "rule.implementation.error.implementation_key.not_available"}
          ]
        })

      {:error, %Changeset{data: %{__struct__: _}} = changeset, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("nested_errors.json",
          changeset: changeset,
          errors: errors,
          prefix: "rule.implementation.error"
        )

      error ->
        Logger.error("While creating rule... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp check_valid_implementation_key(%{"implementation_key" => ""}),
    do: {:valid_implementation_key}

  defp check_valid_implementation_key(%{"implementation_key" => nil}),
    do: {:invalid_implementation_key}

  defp check_valid_implementation_key(%{"implementation_key" => implementation_key}) do
    case valid_format?(implementation_key) do
      true -> {:valid_implementation_key}
      false -> {:invalid_implementation_key}
    end
  end

  defp valid_format?(implementation_key), do: Regex.match?(~r/^[A-z0-9]*$/, implementation_key)

  defp generate_implementation_key(
         %RuleImplementation{implementation_key: implementation_key, id: id} =
           rule_implementation,
         %Rule{} = rule
       ) do
    case implementation_key do
      nil ->
        params = Map.put(%{}, :implementation_key, "ri" <> Integer.to_string(id))

        rule_implementation
        |> Map.put(:rule, rule)
        |> Rules.update_rule_implementation(params)

      _ ->
        {:ok, rule_implementation}
    end
  end

  swagger_path :show do
    description("Show Quality Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleImplementationResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    rule_implementation =
      id
      |> Rules.get_rule_implementation!()
      |> Repo.preload([:rule])
      |> add_rule_results()
      |> add_last_rule_result()
      |> Rules.enrich_rule_implementation_structures()
      |> Rules.enrich_system()

    user = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(user, show(rule_implementation))} do
      render(conn, "show.json", rule_implementation: rule_implementation)
    end
  end

  swagger_path :update do
    description("Updates Quality Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleImplementationUpdate), "Quality Rule update parameters")
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleImplementationResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule_implementation" => rule_implementation_params}) do
    user = conn.assigns[:current_resource]

    update_params =
      rule_implementation_params
      |> decode()
      |> Map.drop([
        :implementation_key,
        "implementation_key",
        :implementation_type,
        "implementation_type"
      ])

    rule_implementation =
      id
      |> Rules.get_rule_implementation!()
      |> Repo.preload([:rule])
      |> add_rule_results()

    rule = rule_implementation.rule

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule_implementation",
      "implementation_type" => rule_implementation.implementation_type
    }

    with {:can, true} <- {:can, can?(user, update(resource_type))},
         {:editable, true} <-
           {:editable,
            Enum.empty?(rule_implementation.all_rule_results) ||
              (Map.keys(rule_implementation_params) == ["soft_delete"] &&
                 Map.get(rule_implementation_params, "soft_delete") == true)},
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.update_rule_implementation(
             rule_implementation,
             with_soft_delete(update_params)
           ) do
      render(conn, "show.json", rule_implementation: rule_implementation)
    else
      {:can, false} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        Logger.error("While updating rule implemenation... #{inspect(changeset)}")

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
        Logger.error("While updating rule implemenation... #{inspect(error)}")

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
    rule_implementation = Rules.get_rule_implementation!(id)
    user = conn.assigns[:current_resource]
    rule = Repo.preload(rule_implementation, :rule).rule

    with {:can, true} <-
           {:can,
            can?(
              user,
              delete(%{
                "business_concept_id" => rule.business_concept_id,
                "resource_type" => "rule_implementation",
                "implementation_type" => rule_implementation.implementation_type
              })
            )},
         {:ok, %RuleImplementation{}} <- Rules.delete_rule_implementation(rule_implementation) do
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

    response(200, "OK", Schema.ref(:RuleImplementationsResponse))
  end

  def search_rule_implementations(conn, %{"rule_id" => id} = params) do
    user = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with {:can, true} <- {:can, can?(user, index(RuleImplementation))} do
      opts = deleted_implementations(params)

      rule_implementations =
        %{"rule_id" => rule_id}
        |> Rules.list_rule_implementations(opts)
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result(&1))
        |> Enum.map(&Rules.enrich_rule_implementation_structures(&1))
        |> Enum.map(&Rules.enrich_system(&1))

      render(conn, "index.json", rule_implementations: rule_implementations)
    end
  end

  swagger_path :search_rules_implementations do
    description("Searh rule implementations")

    parameters do
      search(
        :body,
        Schema.ref(:RuleImplementationsSearchFilters),
        "Filter by Rule, Rule Implementation or structure properties"
      )
    end

    produces("application/json")

    response(200, "OK", Schema.ref(:RuleImplementationsResponse))
  end

  # Endpoint used by DD to search structure implementations
  def search_rules_implementations(conn, %{"structure_id" => structure_id}) do
    user = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(user, index(RuleImplementation))} do
      rule_implementations =
        %{"structure_id" => String.to_integer(structure_id)}
        |> Rules.list_rule_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result(&1))

      render(conn, "index.json", rule_implementations: rule_implementations)
    end
  end

  # Endpoint for dq engine
  def search_rules_implementations(conn, filters) do
    filters = Map.get(filters, "filters", %{})
    user = conn.assigns[:current_resource]
    opts = deleted_implementations(filters)
    opts = Keyword.put(opts, :enrich_structures, true)

    with {:can, true} <- {:can, can?(user, index(RuleImplementation))} do
      rule_implementations =
        filters
        |> Rules.list_rule_implementations(opts)
        |> Enum.map(&Repo.preload(&1, [:rule]))
        |> Enum.map(&add_last_rule_result(&1))

      render(conn, "index.json", rule_implementations: rule_implementations)
    end
  end

  defp add_last_rule_result(rule_implementation) do
    rule_implementation
    |> Map.put(
      :_last_rule_result_,
      Rules.get_latest_rule_result(rule_implementation.implementation_key)
    )
  end

  defp add_rule_results(rule_implementation) do
    rule_implementation
    |> Map.put(
      :all_rule_results,
      Rules.get_rule_implementation_results(rule_implementation.implementation_key)
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
