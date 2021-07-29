defmodule CacheHelpers do
  @moduledoc """
  Support creation of domains in cache
  """

  import TdDd.Factory

  alias TdCache.ConceptCache
  alias TdCache.LinkCache
  alias TdCache.StructureTypeCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.Search.StructureEnricher

  def insert_domain do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    ExUnit.Callbacks.on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)
    _maybe_error = StructureEnricher.refresh()
    domain
  end

  def insert_structure_type(params \\ []) do
    %{id: id} = structure_type = insert(:data_structure_type, params)
    {:ok, _} = StructureTypeCache.put(structure_type)

    ExUnit.Callbacks.on_exit(fn -> StructureTypeCache.delete(id) end)
    _maybe_error = StructureEnricher.refresh()
    structure_type
  end

  def insert_link(data_structure_id, target_id \\ nil) do
    id = System.unique_integer([:positive])
    target_id = if is_nil(target_id), do: System.unique_integer([:positive]), else: target_id

    LinkCache.put(
      %{
        id: id,
        source_type: "data_structure",
        source_id: data_structure_id,
        target_type: "business_concept",
        target_id: target_id,
        updated_at: DateTime.utc_now()
      },
      publish: false
    )

    ExUnit.Callbacks.on_exit(fn -> LinkCache.delete(id, publish: false) end)
    _maybe_error = StructureEnricher.refresh()
    :ok
  end

  def insert_template(params \\ %{}) do
    %{id: template_id} = template = build(:template, params)
    {:ok, _} = TemplateCache.put(template, publish: false)
    ExUnit.Callbacks.on_exit(fn -> TemplateCache.delete(template_id) end)
    _maybe_error = StructureEnricher.refresh()
    template
  end

  def insert_concept(%{} = params \\ %{}) do
    %{id: id} =
      concept =
      params
      |> Map.put_new(:id, System.unique_integer([:positive]))
      |> Map.put_new(:name, "linked concept name")
      |> Map.update(:id, nil, &Integer.to_string/1)

    {:ok, _} = ConceptCache.put(concept)
    ExUnit.Callbacks.on_exit(fn -> ConceptCache.delete(id) end)
    concept
  end

  def insert_user(%{} = params \\ %{}) do
    %{id: id} =
      user =
      params
      |> Map.put_new(:id, System.unique_integer([:positive]))
      |> Map.put_new(:user_name, "user name")
      |> Map.put_new(:full_name, "full name")
      |> Map.put_new(:email, "foo@bar.xyz")

    {:ok, _} = UserCache.put(user)
    ExUnit.Callbacks.on_exit(fn -> UserCache.delete(id) end)
    user
  end
end
