defmodule CacheHelpers do
  @moduledoc """
  Support creation of domains in cache
  """

  import TdDd.Factory

  alias TdCache.AclCache
  alias TdCache.ConceptCache
  alias TdCache.LinkCache
  alias TdCache.Permissions
  alias TdCache.Redix
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.Search.StructureEnricher

  def insert_domain(params \\ %{}) do
    parent_ids = Map.get(params, :parent_ids)
    %{id: domain_id} = domain = build(:domain, params)
    domain = if is_nil(parent_ids), do: domain, else: Map.put(domain, :parent_ids, parent_ids)
    TaxonomyCache.put_domain(domain)
    ExUnit.Callbacks.on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)
    _maybe_error = StructureEnricher.refresh()
    domain
  end

  def insert_structure_type(params \\ []) do
    structure_type = insert(:data_structure_type, params)
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

  def insert_user(params \\ %{}) do
    %{id: id} =
      user =
      params
      |> Map.new()
      |> Map.put_new(:id, System.unique_integer([:positive]))
      |> Map.put_new(:user_name, "user name")
      |> Map.put_new(:full_name, "full name")
      |> Map.put_new(:email, "foo@bar.xyz")

    {:ok, _} = UserCache.put(user)
    ExUnit.Callbacks.on_exit(fn -> UserCache.delete(id) end)
    user
  end

  def insert_acl(domain_id, role, user_ids) do
    AclCache.set_acl_role_users("domain", domain_id, role, user_ids)
    ExUnit.Callbacks.on_exit(fn -> AclCache.delete_acl_roles("domain", domain_id) end)
    :ok
  end

  def insert_grant_request_approver(user_id, domain_id) do
    ExUnit.Callbacks.on_exit(fn ->
      UserCache.delete(user_id)
      Redix.command!(["SREM", "permission:approve_grant_request:roles", "grant_approver"])
    end)
    insert_user(id: user_id)
    insert_acl(domain_id, "grant_approver", [user_id])
    UserCache.put_roles(user_id, %{"grant_approver" => [domain_id]})
    Permissions.put_permission_roles(%{"approve_grant_request" => ["grant_approver"]})
  end
end
