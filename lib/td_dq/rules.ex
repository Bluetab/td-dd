defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Canada, only: [can?: 2]
  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.Repo
  alias TdDfLib.Format
  alias TdDq.Auth.Claims
  alias TdDq.Cache.RuleLoader
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule

  require Logger

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

  def list_rules(params, options) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    query =
      from(
        p in Rule,
        where: ^dynamic,
        where: is_nil(p.deleted_at)
      )

    query
    |> Repo.all()
    |> enrich(Keyword.get(options, :enrich))
  end

  def list_rules_with_bc_id do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], not is_nil(r.business_concept_id))
    |> Repo.all()
    |> Enum.map(&preload_bc_version/1)
  end

  defp preload_bc_version(%{business_concept_id: nil} = rule), do: rule

  defp preload_bc_version(%{business_concept_id: business_concept_id} = rule) do
    case ConceptCache.get(business_concept_id) do
      {:ok, %{name: name, business_concept_version_id: id}} ->
        Map.put(rule, :current_business_concept_version, %{name: name, id: id})

      _ ->
        rule
    end
  end

  defp preload_bc_version(rule), do: rule

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

    Multi.new()
    |> Multi.run(:can, fn _, _ -> multi_can(can?(claims, create(changeset))) end)
    |> Multi.insert(:rule, changeset)
    |> Multi.run(:audit, Audit, :rule_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_create(is_bulk)
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

    Multi.new()
    |> Multi.run(:can, fn _, _ -> multi_can(can?(claims, update(changeset))) end)
    |> Multi.update(:rule, changeset)
    |> Multi.run(:audit, Audit, :rule_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_update()
  end

  defp multi_can(true), do: {:ok, nil}
  defp multi_can(false), do: {:error, false}

  defp on_update(res) do
    with {:ok, %{rule: %{id: rule_id}}} <- res do
      RuleLoader.refresh(rule_id)
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
  def delete_rule(%Rule{} = rule, %Claims{user_id: user_id} = claims) do
    changeset = Rule.delete_changeset(rule)

    Multi.new()
    |> Multi.run(:can, fn _, _ -> multi_can(can?(claims, delete(changeset))) end)
    |> Multi.delete(:rule, changeset)
    |> Multi.run(:audit, Audit, :rule_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
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
    |> Multi.update_all(:deprecated, impls_to_delete, set: [deleted_at: ts])
    |> Multi.update_all(:rules, rules_to_delete, set: [deleted_at: ts])
    |> Multi.run(:audit, Audit, :implementations_deprecated, [])
    # TODO: audit rule deletion?
    |> Repo.transaction()
  end

  def get_rule_or_nil(id) when is_nil(id) or id == "", do: nil
  def get_rule_or_nil(id), do: get_rule(id)

  def get_cached_content(%{} = content, type) when is_binary(type) do
    case TemplateCache.get_by_name!(type) do
      template = %{} ->
        Format.enrich_content_values(content, template)

      _ ->
        content
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

  @spec enrich(Rule.t() | [Rule.t()], nil | atom | [atom]) ::
          Rule.t() | [Rule.t()]
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
end
