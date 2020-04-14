defmodule TdDqWeb.RuleController do
  use TdHypermedia, :controller
  use TdDqWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto.Changeset
  alias Jason, as: JSON
  alias TdCache.EventStream.Publisher
  alias TdDq.Audit
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Rules.Search
  alias TdDqWeb.ChangesetView
  alias TdDqWeb.ErrorView
  alias TdDqWeb.RuleView
  alias TdDqWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  @events %{create_rule: "create_rule", delete_rule: "delete_rule"}

  def swagger_definitions do
    SwaggerDefinitions.rule_definitions()
  end

  swagger_path :index do
    description("List Rules")
    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_resource]
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))
    user_permissions = %{manage_quality_rules: manage_permission}

    rules =
      params
      |> Rules.list_rules()
      |> Enum.filter(&can?(user, show(&1)))

    render(conn, "index.json",
      rules: rules,
      user_permissions: user_permissions
    )
  end

  swagger_path :get_rules_by_concept do
    description("List Rules of a Business Concept")

    parameters do
      id(:path, :string, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:RulesResponse))
  end

  def get_rules_by_concept(conn, %{"id" => id} = params) do
    user = conn.assigns[:current_resource]

    resource_type = %{
      "business_concept_id" => id,
      "resource_type" => "rule"
    }

    with {:can, true} <- {:can, can?(user, get_rules_by_concept(resource_type))} do
      params =
        params
        |> Map.put("business_concept_id", id)
        |> Map.delete("id")

      rules =
        params
        |> Rules.list_concept_rules()
        |> Enum.filter(&can?(user, show(&1)))

      conn
      |> put_view(RuleView)
      |> render(
        "index.json",
        hypermedia: collection_hypermedia("rule", conn, rules, resource_type),
        rules: rules
      )
    end
  end

  swagger_path :create do
    description("Creates a Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleCreate), "Rule create attrs")
    end

    response(201, "Created", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"rule" => rule_params}) do
    user = conn.assigns[:current_resource]

    creation_attrs = Map.put_new(rule_params, "updated_by", user.id)

    resource_type =
      rule_params
      |> Map.take(["business_concept_id"])
      |> Map.put("resource_type", "rule")

    with {:can, true} <- {:can, can?(user, create(resource_type))},
         {:ok, %Rule{} = rule} <- Rules.create_rule(creation_attrs) do
      audit = %{
        "audit" => %{
          "resource_id" => rule.id,
          "resource_type" => "rule",
          "payload" => rule_params
        }
      }

      Audit.create_event(conn, audit, @events.create_rule)

      conn
      |> put_status(:created)
      |> put_resp_header("location", rule_path(conn, :show, rule))
      |> render("show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.type_params.error"
        )

      error ->
        Logger.error("While creating rule... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp get_user_permissions(conn, rule) do
    user = conn.assigns[:current_resource]
    manage_permission = can?(user, manage(%{"resource_type" => "rule"}))

    manage_rule_implementations =
      can?(
        user,
        manage(%{
          "resource_type" => "rule_implementation",
          "business_concept_id" => rule.business_concept_id
        })
      )
    manage_raw_rule_implementations =
      can?(
        user,
        manage_raw(%{
          "resource_type" => "rule_implementation",
          "business_concept_id" => rule.business_concept_id
        })
      )

    %{
      manage_quality_rules: manage_permission,
      manage_quality_rule_implementations: manage_rule_implementations,
      manage_raw_quality_rule_implementations: manage_raw_rule_implementations
    }
  end

  swagger_path :show do
    description("Show Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_resource]

    rule = Rules.get_rule!(id)

    with {:can, true} <- {:can, can?(user, show(rule))} do
      render(
        conn,
        "show.json",
        hypermedia:
          hypermedia("rule", conn, %{
            "business_concept_id" => rule.business_concept_id,
            "resource_type" => "rule"
          }),
        rule: rule,
        user_permissions: get_user_permissions(conn, rule)
      )
    end
  end

  swagger_path :update do
    description("Updates Rule")
    produces("application/json")

    parameters do
      rule(:body, Schema.ref(:RuleUpdate), "Rule update attrs")
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK", Schema.ref(:RuleResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    user = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    update_attrs = Map.put_new(rule_params, "updated_by", user.id)

    with {:can, true} <- {:can, can?(user, update(resource_type))},
         {:ok, %Rule{} = rule} <- Rules.update_rule(rule, update_attrs) do
      render(conn, "show.json", rule: rule, user_permissions: get_user_permissions(conn, rule))
    else
      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )

      {:error, %Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.type_params.error"
        )

      error ->
        Logger.error("While updating rule... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :delete do
    description("Delete Rule")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule ID", required: true)
    end

    response(200, "OK")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_resource]
    rule = Rules.get_rule!(id)

    resource_type = %{
      "business_concept_id" => rule.business_concept_id,
      "resource_type" => "rule"
    }

    with {:can, true} <- {:can, can?(user, delete(resource_type))},
         {:ok, %Rule{}} <- Rules.delete_rule(rule) do
      rule_params =
        rule
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> Map.delete(:rule_implementations)

      audit = %{
        "audit" => %{
          "resource_id" => rule.id,
          "resource_type" => "rule",
          "payload" => rule_params
        }
      }

      Audit.create_event(conn, audit, @events.delete_rule)
      send_resp(conn, :no_content, "")
    else
      {:error, %Changeset{data: %{__struct__: _}} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ChangesetView)
        |> render("error.json",
          changeset: changeset,
          prefix: "rule.error"
        )
    end
  end

  swagger_path :execute_rules do
    description("Execute rules")
    produces("application/json")

    parameters do
      search_params(:body, Schema.ref(:RulesExecuteRequest), "Rules search params")
    end

    response(200, "OK", Schema.ref(:RulesExecuteResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Error while bulk update")
  end

  def execute_rules(conn, %{"search_params" => search_params}) do
    user = conn.assigns[:current_resource]

    rules_ids = search_all_executable_rule_ids(user, search_params)
    event_ids = Enum.join(rules_ids, ",")

    event = %{
      event: "execute_rules",
      rules: "rule_ids:#{event_ids}"
    }

    case Publisher.publish(event, "rules:events") do
      {:ok, _event_id} ->
        body = JSON.encode!(%{data: rules_ids})

        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(:ok, body)

      {:error, error} ->
        Logger.info("While executing rules... #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(:unprocessable_entity, JSON.encode!(%{error: error}))
    end
  end

  defp search_all_executable_rule_ids(_user, %{"rule_ids" => rule_ids}) do
    rule_ids
  end

  defp search_all_executable_rule_ids(user, params) do
    %{results: rules} =
      params
      |> Map.drop(["page", "size"])
      |> Search.search(user, 0, 10_000)

    Enum.map(rules, &Map.get(&1, :id))
  end
end
