defmodule TdDqWeb.RuleImplementationController do
  require Logger
  use TdDqWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDq.Repo
  alias TdDq.Rules
  alias TdDq.Rules
  alias TdDq.Rules.RuleImplementation
  alias TdDqWeb.ErrorView
  alias TdDqWeb.SwaggerDefinitions

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.rule_implementation_definitions()
  end

  swagger_path :index do
    description "List Quality Rules"
    response 200, "OK", Schema.ref(:RuleImplementationsResponse)
  end

  def index(conn, _params) do
    user = conn.assigns[:current_resource]
    with true <- can?(user, index(RuleImplementation)) do
      rule_implementations = Rules.list_rule_implementations()
      render(conn, "index.json", rule_implementations: rule_implementations)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      error ->
        Logger.error("While getting rule implementations... #{inspect(error)}")
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :create do
    description "Creates a Quality Rule"
    produces "application/json"
    parameters do
      rule_implementation :body, Schema.ref(:RuleImplementationCreate), "Quality Rule create attrs"
    end
    response 201, "Created", Schema.ref(:RuleImplementationResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"rule_implementation" => rule_implementation_params}) do
    user = conn.assigns[:current_resource]
    rule_id = Map.fetch!(rule_implementation_params, "rule_id")
    rule = Rules.get_rule!(rule_id)

    {rule_implementation_params, rule_type} =
      add_rule_type_id(rule_implementation_params)

    with true <- can?(user, create(%{
          "business_concept_id" => rule.business_concept_id,
          "resource_type" => "rule_implementation"
          })),
         {:valid_rule_type} <- verify_rule_implementation_existence(rule_type),
         {:ok_size_verification} <- verify_equals_sizes(rule_implementation_params, rule_type.params),
         {:ok_existence_verification} <- verify_types_and_existence(rule_implementation_params, rule_type.params),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.create_rule_implementation(rule_implementation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_implementation_path(conn, :show, rule_implementation))
      |> render("show.json", rule_implementation: rule_implementation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp verify_rule_implementation_existence(rule_type) do
    if rule_type, do: {:valid_rule_type},
    else: {:not_found_rule_type}
  end

  defp verify_equals_sizes(%{"system_params" => rule_implementation_params}, %{"system_params" => qrt_params}) do
    case length(Map.keys(rule_implementation_params)) == length(qrt_params) do
      true -> {:ok_size_verification}
      false -> {:ko_size_verification}
    end
  end
  defp verify_equals_sizes(%{"system_params" => system_params}, _map_rule_type) when system_params == %{}, do: {:ok_size_verification}
  defp verify_equals_sizes(_map_rule_implementation, _map_rule_type), do: {:no_system_params}

  defp verify_types_and_existence(map_rule_implementation_params,
    map_rule_type_params) do
      qr_tuple_list = Enum.map(map_rule_implementation_params["system_params"], fn({k, v}) ->
        {k, get_type(v)}
      end)
      verify_key_type(qr_tuple_list, map_rule_type_params["system_params"])
  end

  defp verify_key_type(_, _, {:error, error}), do: error
  defp verify_key_type([], _), do: {:ok_existence_verification}
  defp verify_key_type([{k, v}|tail], system_params) do
    system_param = Enum.find(system_params, fn(param) ->
      param["name"] == k
    end)
    cond do
      system_param == nil ->
        verify_key_type(nil, nil, {:error, "Element not found"})
      system_param["type"] != v ->
        verify_key_type(nil, nil, {:error, "Type does not match"})
      true ->   verify_key_type(tail, system_params)
    end
  end

  defp get_type(value) when is_integer(value), do: "integer"
  defp get_type(value) when is_float(value), do: "float"
  defp get_type(value) when is_list(value), do: "list"
  defp get_type(value) when is_boolean(value), do: "boolean"
  defp get_type(_), do: "string"

  swagger_path :show do
    description "Show Quality Rule"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 200, "OK", Schema.ref(:RuleImplementationResponse)
    response 400, "Client Error"
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
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :update do
    description "Updates Quality Rule"
    produces "application/json"
    parameters do
      rule :body, Schema.ref(:RuleImplementationUpdate), "Quality Rule update attrs"
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 200, "OK", Schema.ref(:RuleImplementationResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "rule_implementation" => rule_implementation_params}) do
    rule_implementation = Rules.get_rule_implementation!(id)
    rule = rule_implementation.rule

    user = conn.assigns[:current_resource]
    with true <- can?(user, update(%{
        "business_concept_id" => rule.business_concept_id,
        "resource_type" => "rule_implementation"
        })),
         {:ok, %RuleImplementation{} = rule_implementation} <-
           Rules.update_rule_implementation(rule_implementation, rule_implementation_params) do
      render(conn, "show.json", rule_implementation: rule_implementation)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :delete do
    description "Delete Quality Rule"
    produces "application/json"
    parameters do
      id :path, :integer, "Quality Rule ID", required: true
    end
    response 204, "No Content"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    rule_implementation = Rules.get_rule_implementation!(id)
    user = conn.assigns[:current_resource]
    rule = rule_implementation.rule

    with true <- can?(user, delete(%{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule_implementation"
      })),
         {:ok, %RuleImplementation{}} <- Rules.delete_rule_implementation(rule_implementation) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :get_rule_implementations do
    description "List Quality Rules"
    parameters do
      id :path, :integer, "Rule ID", required: true
    end
    response 200, "OK", Schema.ref(:RuleImplementationsResponse)
  end

  def get_rule_implementations(conn, %{"rule_id" => id}) do
    user = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with true <- can?(user, index(RuleImplementation)) do
      rule_implementations = Rules.list_rule_implementations()

      # TODO: Search rule implementations by rule
      # TODO: Preload rule in search
      rule_implementations = rule_implementations
      |> Enum.map(&Repo.preload(&1, :rule))
      |> Enum.filter(&(&1.rule_id == rule_id))

      rules_results = rule_implementations
      |> Enum.reduce(%{}, fn(rule_implementation, acc) ->
          Map.put(acc, rule_implementation.id,
            get_concept_last_rule_result(rule_implementation))
      end)

      render(conn, "index.json", rule_implementations: rule_implementations,
                            rules_results: rules_results)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      error ->
        Logger.error("While getting rule implementations... #{inspect(error)}")
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  # TODO: Search by implemnetation id
  defp get_concept_last_rule_result(rule_implementation) do
    system_params = rule_implementation.system_params
    table = Map.get(system_params, "table", nil)
    column = Map.get(system_params, "column", nil)
    case  table == nil or column == nil do
      true -> nil
      false -> nil
        Rules.get_concept_last_rule_result(
            rule_implementation.rule.business_concept_id,
            rule_implementation.rule.name,
            rule_implementation.system,
            table,
            column)
    end
  end

  defp add_rule_type_id(%{"type" => qrt_name} = rule_implementation_params) do
    qrt = Rules.get_rule_type_by_name(qrt_name)
    case qrt do
      nil ->
        {rule_implementation_params, nil}
      qrt ->
        {rule_implementation_params
        |> Map.put("rule_type_id", qrt.id), qrt}
    end
  end
  defp add_rule_type_id(%{"rule_type_id" => rule_type_id} = rule_implementation_params),
    do: {rule_implementation_params, Rules.get_rule_type!(rule_type_id)}
  defp add_rule_type_id(rule_implementation_params), do: {rule_implementation_params, nil}
end
