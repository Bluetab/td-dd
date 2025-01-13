defmodule TdDdWeb.Schema do
  @moduledoc """
  Absinthe Schema definitions
  """

  use Absinthe.Schema

  alias TdDd.DataStructures
  alias TdDd.Repo
  alias TdDdWeb.Schema.Middleware
  alias TdDq.Implementations
  alias TdDq.Rules.RuleResults

  import_types(Absinthe.Plug.Types)
  import_types(Absinthe.Type.Custom)
  import_types(TdDdWeb.Schema.CatalogViewConfigs)
  import_types(TdDdWeb.Schema.Commond)
  import_types(TdDdWeb.Schema.DataStructureLinks)
  import_types(TdDdWeb.Schema.Labels)
  import_types(TdDdWeb.Schema.Domains)
  import_types(TdDdWeb.Schema.Executions)
  import_types(TdDdWeb.Schema.Functions)
  import_types(TdDdWeb.Schema.Grants)
  import_types(TdDdWeb.Schema.GrantApprovalRules)
  import_types(TdDdWeb.Schema.GrantRequests)
  import_types(TdDdWeb.Schema.ImplementationResults)
  import_types(TdDdWeb.Schema.Implementations)
  import_types(TdDdWeb.Schema.Me)
  import_types(TdDdWeb.Schema.ReferenceData)
  import_types(TdDdWeb.Schema.Remediations)
  import_types(TdDdWeb.Schema.Rules)
  import_types(TdDdWeb.Schema.Sources)
  import_types(TdDdWeb.Schema.StructureNotes)
  import_types(TdDdWeb.Schema.Structures)
  import_types(TdDdWeb.Schema.StructureTags)
  import_types(TdDdWeb.Schema.Tags)
  import_types(TdDdWeb.Schema.Tasks)
  import_types(TdDdWeb.Schema.Templates)
  import_types(TdDdWeb.Schema.Types.Custom.Cursor)
  import_types(TdDdWeb.Schema.Types.Custom.DataURL)
  import_types(TdDdWeb.Schema.Types.Custom.JSON)
  import_types(TdDdWeb.Schema.Types.Custom.DateFilter)
  import_types(TdDdWeb.Schema.User)

  query do
    import_fields(:domain_queries)
    import_fields(:function_queries)
    import_fields(:grant_queries)
    import_fields(:catalog_view_config_queries)
    import_fields(:grant_request_queries)
    import_fields(:grant_approval_rules_queries)
    import_fields(:implementation_queries)
    import_fields(:implementation_results_queries)
    import_fields(:label_queries)
    import_fields(:me_queries)
    import_fields(:reference_data_queries)
    import_fields(:remediation_queries)
    import_fields(:rule_queries)
    import_fields(:source_queries)
    import_fields(:structure_note_queries)
    import_fields(:structure_queries)
    import_fields(:tag_queries)
    import_fields(:template_queries)
    import_fields(:task_query)
  end

  mutation do
    import_fields(:catalog_view_config_mutations)
    import_fields(:grant_approval_rules_mutations)
    import_fields(:implementation_mutations)
    import_fields(:reference_data_mutations)
    import_fields(:source_mutations)
    import_fields(:structure_tag_mutations)
    import_fields(:tag_mutations)
  end

  def context(ctx) do
    timeout = Application.get_env(:td_dd, Repo)[:timeout]

    loader =
      Dataloader.new()
      |> Dataloader.add_source(DataStructures, DataStructures.datasource())
      |> Dataloader.add_source(RuleResults, RuleResults.datasource())
      |> Dataloader.add_source(Implementations, Implementations.datasource())
      |> Dataloader.add_source(TdDq.Rules, TdDq.Rules.datasource())
      |> Dataloader.add_source(TdDq.Executions, TdDq.Executions.datasource())
      |> Dataloader.add_source(
        TdDq.Executions.KV,
        Dataloader.KV.new(&TdDq.Executions.kv_datasource/2, timeout: timeout)
      )
      |> Dataloader.add_source(TdCx.Sources, TdCx.Sources.datasource())
      |> Dataloader.add_source(:domain_actions, Dataloader.KV.new(fetch_permission_domains(ctx)))

    Map.put(ctx, :loader, loader)
  end

  defp fetch_permission_domains(ctx) do
    fn batch_key, ids ->
      TdDdWeb.Resolvers.Domains.fetch_permission_domains(batch_key, ids, ctx)
    end
  end

  def middleware(middleware, %{identifier: field}, %{identifier: :query}) do
    [
      {Middleware.Authorize, [action: :query, resource: field]} | middleware
    ]
  end

  def middleware(middleware, %{identifier: field}, %{identifier: :mutation}) do
    [
      {Middleware.Authorize, [action: :mutation, resource: field]} | middleware
    ]
  end

  def middleware(
        middleware,
        %{identifier: field_identifier} = field,
        %{identifier: object_identifier} = object
      )
      when object_identifier in [:template_field, :template_content] do
    key = Atom.to_string(field_identifier)
    new_middleware_spec = {{__MODULE__, :get_string_key}, key}
    Absinthe.Schema.replace_default(middleware, new_middleware_spec, field, object)
  end

  def middleware(middleware, _field, _obj), do: middleware

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end

  def get_string_key(%{source: source} = res, key) do
    %{res | state: :resolved, value: Map.get(source, key)}
  end
end
