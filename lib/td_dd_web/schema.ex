defmodule TdDdWeb.Schema do
  @moduledoc """
  Absinthe Schema definitions
  """

  use Absinthe.Schema

  alias TdDdWeb.Schema.Middleware

  import_types(Absinthe.Plug.Types)
  import_types(Absinthe.Type.Custom)
  import_types(TdDdWeb.Schema.Domains)
  import_types(TdDdWeb.Schema.Implementations)
  import_types(TdDdWeb.Schema.ImplementationResults)
  import_types(TdDdWeb.Schema.ReferenceData)
  import_types(TdDdWeb.Schema.Rules)
  import_types(TdDdWeb.Schema.Sources)
  import_types(TdDdWeb.Schema.StructureNotes)
  import_types(TdDdWeb.Schema.Structures)
  import_types(TdDdWeb.Schema.StructureTags)
  import_types(TdDdWeb.Schema.Templates)
  import_types(TdDdWeb.Schema.Types.Custom.DataURL)
  import_types(TdDdWeb.Schema.Types.Custom.JSON)

  query do
    import_fields(:domain_queries)
    import_fields(:reference_data_queries)
    import_fields(:rule_queries)
    import_fields(:source_queries)
    import_fields(:structure_note_queries)
    import_fields(:structure_queries)
    import_fields(:structure_tag_queries)
    import_fields(:template_queries)
    import_fields(:implementation_queries)
    import_fields(:implementation_results_queries)
  end

  mutation do
    import_fields(:source_mutations)
    import_fields(:reference_data_mutations)
    import_fields(:structure_tag_mutations)
    import_fields(:implementation_mutations)
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(TdDd.DataStructures, TdDd.DataStructures.datasource())
      |> Dataloader.add_source(TdCx.Sources, TdCx.Sources.datasource())

    Map.put(ctx, :loader, loader)
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
