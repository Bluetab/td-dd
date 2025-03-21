defmodule TdDqWeb.ImplementationController do
  use TdDqWeb, :controller

  alias TdCluster.Cluster.TdLm, as: Cluster

  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Actions
  alias TdDq.Implementations.Download
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.Search
  alias TdDq.Rules
  alias TdDq.Rules.RuleResults

  @default_lang "es"

  @state_permission_map %{
    "published" => :view_published_concept,
    "draft" => :view_draft_concept,
    "pending_approval" => :view_approval_pending_concept
  }

  action_fallback(TdDqWeb.FallbackController)

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    filters =
      %{}
      |> add_rule_filter(params, "rule_business_concept_id", "business_concept_id")
      |> add_rule_filter(params, "is_rule_active", "active")

    with :ok <- Bodyguard.permit(Implementations, :query, claims) do
      implementations =
        filters
        |> Implementations.list_implementations(preload: [:rule, :results], enrich: :source)
        |> Enum.map(
          &Implementations.enrich_implementation_structures(&1, preload_structures: true)
        )

      conn
      |> Actions.put_actions(claims, Implementation)
      |> render("index.json", implementations: implementations)
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

  def create(conn, %{
        "rule_implementation" =>
          %{"operation" => "clone", "implementation_ref" => original_implementation_ref} = params
      }) do
    claims = conn.assigns[:current_resource]

    with {:ok, %{implementation: %{id: id}}} <-
           Implementations.create_ruleless_implementation(params, claims),
         implementation <-
           Implementations.get_implementation!(id, enrich: :source, preload: [:results]) do
      Cluster.clone_relations(
        original_implementation_ref,
        id,
        "business_concept",
        claims
      )

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.implementation_path(conn, :show, implementation))
      |> render("show.json", implementation: implementation)
    end
  end

  def create(conn, %{"rule_implementation" => %{"rule_id" => rule_id} = params})
      when not is_nil(rule_id) do
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

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    locale = conn.assigns[:locale]

    implementation =
      id
      |> Implementations.get_implementation!(
        enrich: [:source, :links, :domain],
        preload: [:rule],
        lang: locale
      )
      |> add_last_rule_result()
      |> add_quality_event()
      |> Implementations.enrich_implementation_structures(preload_structures: true)
      |> filter_links_by_permission(claims)
      |> filter_data_structures_by_permission(claims)

    with :ok <- Bodyguard.permit(Implementations, :view, claims, implementation) do
      conn
      |> Actions.put_actions(claims, implementation)
      |> render("show.json", implementation: implementation)
    end
  end

  defp filter_links_by_permission(implementation, %{role: "admin"}), do: implementation

  defp filter_links_by_permission(%{links: [_ | _] = links} = implementation, claims) do
    permitted_links =
      Enum.filter(links, fn %{status: status} = link ->
        case Map.get(@state_permission_map, status) do
          nil ->
            false

          permission ->
            has_permission?(claims, link, permission)
        end
      end)

    Map.put(
      implementation,
      :links,
      permitted_links
    )
  end

  defp filter_links_by_permission(implementation, _claims), do: implementation

  defp has_permission?(claims, %{resource_type: :concept, domain_id: domain_id}, permission) do
    Bodyguard.permit(Implementations, permission, claims, domain_id)
  end

  defp filter_data_structures_by_permission(implementation, %{role: "admin"}), do: implementation

  defp filter_data_structures_by_permission(
         %{data_structures: [_ | _] = data_structures} = implementation,
         claims
       ) do
    data_structures =
      Enum.filter(data_structures, fn %{data_structure: data_structure} ->
        Bodyguard.permit?(TdDd.DataStructures, :view_data_structure, claims, data_structure)
      end)

    Map.put(implementation, :data_structures, data_structures)
  end

  defp filter_data_structures_by_permission(implementation, _claims), do: implementation

  def update(conn, %{"id" => id, "rule_implementation" => implementation_params}) do
    claims = conn.assigns[:current_resource]

    implementation = Implementations.get_implementation!(id)

    with :ok <- Bodyguard.permit(Implementations, :edit, claims, implementation),
         {:ok, %{implementation: %{id: id}} = update_info} <-
           Implementations.maybe_update_implementation(
             implementation,
             implementation_params,
             claims
           ),
         error <- Map.get(update_info, :error, :nothing),
         implementation <-
           Implementations.get_implementation!(id, enrich: :source, preload: [:rule, :results]) do
      render(conn, "show.json", implementation: implementation, error: error)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    implementation = Implementations.get_implementation!(id)

    with :ok <- Bodyguard.permit(Implementations, :delete, claims, implementation),
         {:ok, _} <-
           Implementations.delete_implementation(implementation, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  def search_rule_implementations(conn, %{"rule_id" => id} = params) do
    claims = conn.assigns[:current_resource]
    rule_id = String.to_integer(id)

    with :ok <- Bodyguard.permit(Implementations, :query, claims),
         implementations <- Search.search_by_rule_id(params, claims, rule_id, 0, 1000) do
      conn
      |> Actions.put_actions(claims)
      |> render("index.json", implementations: implementations)
    end
  end

  def csv(conn, params) do
    claims = conn.assigns[:current_resource]

    {header_labels, params} = Map.pop(params, "header_labels", %{})
    {content_labels, params} = Map.pop(params, "content_labels", %{})
    {lang, params} = Map.pop(params, "lang", @default_lang)

    %{results: implementations} = search_all_implementations(params, claims)

    case implementations do
      [] ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", "attachment; filename=\"implementations.zip\"")
        |> send_resp(:ok, Download.to_csv(implementations, header_labels, content_labels, lang))
    end
  end

  defp search_all_implementations(params, claims) do
    params
    |> Map.put("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> Search.scroll_implementations(claims)
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
end
