defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TdCache.ConceptCache
  alias TdCache.TemplateCache
  alias TdDfLib.Format
  alias TdDq.Cache.RuleLoader
  alias TdDq.Repo
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Implementations
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  require Logger

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules(params \\ %{})

  def list_rules(rule_ids) when is_list(rule_ids) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^rule_ids)
    |> Repo.all()
  end

  def list_rules(params) do
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
  end

  def list_rules_with_bc_id do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], not is_nil(r.business_concept_id))
    |> Repo.all()
    |> Enum.map(&preload_bc_version/1)
  end

  def list_all_rules do
    Rule
    |> where([r], is_nil(r.deleted_at))
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
  def get_rule!(id) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get!(id)
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
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(%{} = params, %{id: user_id} = _user) do
    changeset = Rule.changeset(params)

    Multi.new()
    |> Multi.insert(:rule, changeset)
    |> Multi.run(:audit, Audit, :rule_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_create()
  end

  defp on_create(res) do
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
  def update_rule(%Rule{} = rule, %{} = params, %{id: user_id} = _user) do
    changeset =
      rule
      |> Repo.preload(:rule_implementations)
      |> Rule.changeset(params)

    Multi.new()
    |> Multi.update(:rule, changeset)
    |> Multi.run(:audit, Audit, :rule_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_update()
  end

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
  def delete_rule(%Rule{} = rule, %{id: user_id}) do
    changeset = Rule.delete_changeset(rule)

    Multi.new()
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

  def list_concept_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    from(
      p in Rule,
      where: ^dynamic,
      where: is_nil(p.deleted_at),
      order_by: [desc: :business_concept_id]
    )
    |> Repo.all()
  end

  def get_rule_by_implementation_key(implementation_key, opts \\ []) do
    implementation_rule =
      implementation_key
      |> Implementations.get_implementation_by_key(opts[:deleted])
      |> Repo.preload(:rule)

    case implementation_rule do
      nil -> nil
      _rule -> Map.get(implementation_rule, :rule)
    end
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
end
