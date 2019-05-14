defmodule TdDqWeb.RuleImplementationController do
  require Logger
  use TdDqWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]
  alias Ecto.Changeset
  alias TdDq.Repo
  alias TdDq.Rules
  alias TdDq.Rules.RuleImplementation
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
  alias TdDqWeb.SwaggerDefinitions

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

    with true <- can?(user, index(RuleImplementation)) do
      rule_implementations =
        filters
        |> Rules.list_rule_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule, rule: :rule_type]))

      render(conn, "index.json", rule_implementations: rule_implementations)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While getting rule implementations... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
        "Quality Rule create attrs"
      )
    end

    response(201, "Created", Schema.ref(:RuleImplementationResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule_implementation" => rule_implementation_params}) do
    user = conn.assigns[:current_resource]
    rule_id = rule_implementation_params["rule_id"]
    rule = Rules.get_rule_or_nil(rule_id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule_implementation"
    }

    with true <- can?(user, create(resource_type)),
         {:valid_implementation_key} <-
           check_valid_implementation_key(rule_implementation_params),
         {:implementation_key_available} <-
           Rules.check_available_implementation_key(rule_implementation_params),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.create_rule_implementation(rule, rule_implementation_params),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           generate_implementation_key(rule_implementation) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_implementation_path(conn, :show, rule_implementation))
      |> render("show.json", rule_implementation: rule_implementation)
    else
      false ->
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

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
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
         %RuleImplementation{implementation_key: implementation_key, id: id} = rule_implementation
       ) do
    case implementation_key do
      nil ->
        new_rule_implementation =
          rule_implementation
          |> Map.put(:implementation_key, "ri" <> Integer.to_string(id))

        rule_implementation
        |> Rules.update_rule_implementation(Map.from_struct(new_rule_implementation))

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
    rule_implementation = Rules.get_rule_implementation!(id)
    user = conn.assigns[:current_resource]

    with true <- can?(user, show(rule_implementation)) do
      render(conn, "show.json", rule_implementation: rule_implementation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :update do
    description("Updates Quality Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleImplementationUpdate), "Quality Rule update attrs")
      id(:path, :integer, "Quality Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleImplementationResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule_implementation" => rule_implementation_params}) do
    user = conn.assigns[:current_resource]

    rule_implementation =
      id
      |> Rules.get_rule_implementation!()
      |> Repo.preload([:rule, rule: :rule_type])

    rule = rule_implementation.rule

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule_implementation"
    }

    with true <- can?(user, update(resource_type)),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.update_rule_implementation(rule_implementation, rule_implementation_params) do
      render(conn, "show.json", rule_implementation: rule_implementation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
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

    with true <-
           can?(
             user,
             delete(%{
               "business_concept_id" => rule.business_concept_id,
               "resource_type" => "rule_implementation"
             })
           ),
         {:ok, %RuleImplementation{}} <- Rules.delete_rule_implementation(rule_implementation) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :get_rule_implementations do
    description("List Quality Rules")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleImplementationsResponse))
  end

  def get_rule_implementations(conn, %{"rule_id" => id}) do
    user = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with true <- can?(user, index(RuleImplementation)) do
      rule_implementations =
        %{"rule_id" => rule_id}
        |> Rules.list_rule_implementations()
        |> Enum.map(&Repo.preload(&1, [:rule, [rule: :rule_type]]))
        |> Enum.map(&add_last_rule_result(&1))

      render(conn, "index.json", rule_implementations: rule_implementations)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      error ->
        Logger.error("While getting rule implementations... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp add_last_rule_result(rule_implementation) do
    rule_implementation
    |> Map.put(
      :_last_rule_result_,
      Rules.get_last_rule_result(rule_implementation.implementation_key)
    )
  end
end
