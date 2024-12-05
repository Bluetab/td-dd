defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.LinkCache
  alias TdCache.TagCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.Repo
  alias TdDfLib.Format
  alias TdDq.Cache.RuleLoader
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.Search.Indexer
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule
  alias Truedat.Auth.Claims

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules(params \\ %{}, options \\ [])

  def list_rules(rule_ids, options) when is_list(rule_ids) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^rule_ids)
    |> Repo.all()
    |> enrich(Keyword.get(options, :enrich))
  end

  def list_rules(params, opts) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    from(
      p in Rule,
      where: ^dynamic,
      where: is_nil(p.deleted_at)
    )
    |> Repo.all()
    |> maybe_merge_childs(params, Keyword.get(opts, :childs))
    |> enrich(Keyword.get(opts, :enrich))
  end

  defp maybe_merge_childs(rules, %{"business_concept_id" => id}, true) do
    expandable_tags = TagCache.list_types(expandable: "true")

    child_business_concepts =
      "business_concept"
      |> LinkCache.list(id, childs: true)
      |> then(&elem(&1, 1))
      |> Enum.filter(fn
        %{resource_type: :concept, tags: tags} -> length(tags -- tags -- expandable_tags) > 0
        _ -> false
      end)
      |> Enum.into(%{}, &{String.to_integer(&1.resource_id), &1.name})

    bc_ids = Map.keys(child_business_concepts)

    from(
      p in Rule,
      where: p.business_concept_id in ^bc_ids,
      where: is_nil(p.deleted_at)
    )
    |> Repo.all()
    |> Enum.map(
      &%{&1 | business_concept_name: Map.get(child_business_concepts, &1.business_concept_id)}
    )
    |> Enum.concat(rules)
  end

  defp maybe_merge_childs(rules, _, _), do: rules

  @doc """
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule!(id, options \\ []) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get!(id)
    |> enrich(Keyword.get(options, :enrich))
  end

  @doc """
  Gets a single rule.

  ## Examples

      iex> get_rule(123)
      %Rule{}

      iex> get_rule(456)
      ** nil

  """
  def get_rule(id) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get(id)
  end

  @doc """
  Gets a single rule by name

  ## Examples

      iex> get_rule("bar")
      %Rule{}

      iex> get_rule("bar")
      ** nil

  """
  def get_rule_by_name(nil), do: nil

  def get_rule_by_name(name) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get_by(name: name)
  end

  @doc """
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(%{} = params, %Claims{user_id: user_id} = claims, is_bulk \\ false) do
    changeset = Rule.changeset(%Rule{updated_by: user_id}, params)

    with :ok <- Bodyguard.permit(__MODULE__, :create, claims, changeset) do
      Multi.new()
      |> Multi.insert(:rule, changeset)
      |> Multi.run(:audit, Audit, :rule_created, [changeset, user_id])
      |> Repo.transaction()
      |> on_create(is_bulk)
    end
  end

  defp on_create(res, true), do: res

  defp on_create(res, false) do
    with {:ok, %{rule: %{id: rule_id}}} <- res do
      RuleLoader.refresh(rule_id)
      res
    end
  end

  @doc """
  Updates a rule.

  ## Examples

      iex> update_rule(rule, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_rule(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule(%Rule{} = rule, %{} = params, %Claims{user_id: user_id} = claims) do
    changeset = Rule.changeset(rule, params, user_id)

    with :ok <- Bodyguard.permit(__MODULE__, :update, claims, changeset) do
      Multi.new()
      |> Multi.update(:rule, changeset)
      |> Multi.update_all(:implementations, &update_domain_id(&1.rule), [])
      |> Multi.run(:audit, Audit, :rule_updated, [changeset, user_id])
      |> Repo.transaction()
      |> on_update()
    end
  end

  defp update_domain_id(%{id: rule_id, domain_id: domain_id, updated_at: updated_at}) do
    Implementation
    |> where([i], i.rule_id == ^rule_id)
    |> where([i], i.domain_id != ^domain_id)
    |> select([i], i.id)
    |> update([i], set: [domain_id: ^domain_id, updated_at: ^updated_at])
  end

  defp on_update(res) do
    with {:ok, %{implementations: {_, implementation_ids}, rule: %{id: rule_id}}} <- res do
      RuleLoader.refresh(rule_id)
      Indexer.reindex(implementation_ids)
      res
    end
  end

  @doc """
  Deletes a Rule.

  ## Examples

      iex> delete_rule(rule)
      {:ok, %Rule{}}

      iex> delete_rule(rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule(%Rule{} = rule, %{user_id: user_id} = claims) do
    changeset = Rule.delete_changeset(rule)

    with :ok <- Bodyguard.permit(__MODULE__, :delete, claims, changeset) do
      Multi.new()
      |> Multi.update(:rule, changeset)
      |> Multi.run(:audit, Audit, :rule_deleted, [user_id])
      |> Repo.transaction()
      |> on_delete()
    end
  end

  defp on_delete(res) do
    with {:ok, %{rule: %{id: rule_id}}} <- res do
      RuleLoader.delete(rule_id)
    end

    res
  end

  def soft_deletion(active_ids, ts \\ DateTime.utc_now()) do
    case do_soft_deletion(active_ids, ts) do
      {:ok, %{rules: {_, rule_ids}} = results} ->
        RuleLoader.delete(rule_ids)

        {:ok, results}

      error ->
        error
    end
  end

  defp do_soft_deletion(active_ids, ts) do
    rules_to_delete =
      Rule
      |> where([r], is_nil(r.deleted_at))
      |> where([r], not is_nil(r.business_concept_id))
      |> where([r], r.business_concept_id not in ^active_ids)
      |> select([r], r.id)

    impls_to_delete =
      Implementation
      |> join(:inner, [ri], r in assoc(ri, :rule))
      |> where([i], is_nil(i.deleted_at))
      |> where([_, r], not is_nil(r.business_concept_id))
      |> where([_, r], is_nil(r.deleted_at))
      |> where([_, r], r.business_concept_id not in ^active_ids)
      |> select([ri, _], ri)

    Multi.new()
    |> Multi.update_all(:deprecated, impls_to_delete, set: [deleted_at: ts, status: "deprecated"])
    |> Multi.update_all(:rules, rules_to_delete, set: [deleted_at: ts])
    |> Multi.run(:audit, Audit, :implementations_deprecated, [])
    # TODO: audit rule deletion?
    |> Repo.transaction()
  end

  def get_rule_or_nil(id) when is_nil(id) or id == "", do: nil
  def get_rule_or_nil(id), do: get_rule(id)

  def get_cached_content(%{} = content, type) when is_binary(type) do
    case TemplateCache.get_by_name!(type) do
      template = %{} -> Format.enrich_content_values(content, template, [:system, :hierarchy])
      _ -> content
    end
  end

  def get_cached_content(content, _type), do: content

  defp filter(params, fields) do
    params
    |> Map.new(fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      kv -> kv
    end)
    |> Map.take(fields)
    |> Enum.reject(fn {_, v} -> is_map(v) end)
    |> Enum.reduce(_dynamic = true, fn {field, value}, acc ->
      dynamic([p], field(p, ^field) == ^value and ^acc)
    end)
  end

  defp enrich(target, nil), do: target

  defp enrich(target, opts) when is_list(target) do
    Enum.map(target, &enrich(&1, opts))
  end

  defp enrich(target, opts) when is_list(opts) do
    Enum.reduce(opts, target, &enrich(&2, &1))
  end

  defp enrich(%Rule{domain_id: domain_id} = rule, :domain) when is_integer(domain_id) do
    case TaxonomyCache.get_domain(domain_id) do
      %{id: ^domain_id} = domain ->
        %{rule | domain: Map.take(domain, [:id, :name, :external_id])}

      _ ->
        rule
    end
  end

  defp enrich(target, _), do: target

  ## Dataloader
  def datasource do
    timeout = Application.get_env(:td_dd, TdDd.Repo)[:timeout]
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: timeout)
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn
      {:preload, preload}, q -> preload(q, ^preload)
    end)
  end
end
