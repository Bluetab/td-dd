defmodule TdDq.Rules.Audit do
  @moduledoc """
  The Rules Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDq.Audit.AuditSupport, only: [publish: 1, publish: 4, publish: 5]

  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache
  alias TdDq.Rules

  @doc """
  Publishes a `:rule_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_created(_repo, %{rule: %{id: id}}, %{} = changeset, user_id) do
    publish("rule_created", "rule", id, user_id, changeset)
  end

  @doc """
  Publishes a `:rule_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_updated(_repo, %{rule: %{id: id}}, %{} = changeset, user_id) do
    publish("rule_updated", "rule", id, user_id, changeset)
  end

  @doc """
  Publishes a `:rule_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_deleted(_repo, %{rule: %{id: id}}, user_id) do
    publish("rule_deleted", "rule", id, user_id)
  end

  @doc """
  Publishes an `:implementation_created` event. Should be called using
  `Ecto.Multi.run/5`.
  """
  def implementation_created(
        _repo,
        %{implementation: %{id: id, rule_id: rule_id} = implementation},
        _changeset,
        user_id
      ) do
    %{name: rule_name} = Rules.get_rule!(rule_id)

    payload =
      implementation
      |> Map.take([:implementation_key, :rule_id, :domain_id])
      |> Map.put(:rule_name, rule_name)

    publish("implementation_created", "implementation", id, user_id, payload)
  end

  @doc """
  Publishes `:implementation_deleted` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementation_deleted(
        _repo,
        %{implementation: %{id: id} = implementation},
        _changeset,
        user_id
      ) do
    payload = Map.take(implementation, [:implementation_key, :rule_id, :domain_id])
    publish("implementation_deleted", "implementation", id, user_id, payload)
  end

  @doc """
  Publishes `:implementation_deprecated` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementations_deprecated(_repo, %{deprecated: {_, [_ | _] = impls}}) do
    impls
    |> Enum.map(fn %{id: id} = implementation ->
      payload = Map.take(implementation, [:implementation_key, :rule_id, :domain_id])
      publish("implementation_deprecated", "implementation", id, 0, payload)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: event_ids} -> {:ok, event_ids}
    end
  end

  def implementations_deprecated(_repo, _), do: {:ok, []}

  @doc """
  Publishes an `implementation_updated` event (or `implementation_deprecated`,
  `implementation_restored`, `implementation_moved`, `implementation_changed`).
  Should be called using `Ecto.Multi.run/5`.
  """
  def implementation_updated(repo, implementation, changeset, user_id)

  def implementation_updated(
        _repo,
        %{implementation: %{id: id} = implementation},
        %{changes: %{deleted_at: deleted_at}},
        user_id
      ) do
    payload = Map.take(implementation, [:implementation_key, :rule_id, :domain_id])

    event =
      if is_nil(deleted_at) do
        "implementation_restored"
      else
        "implementation_deprecated"
      end

    publish(event, "implementation", id, user_id, payload)
  end

  def implementation_updated(
        _repo,
        %{implementation: %{id: id} = implementation},
        %{changes: %{rule_id: rule_id}},
        user_id
      ) do
    %{name: rule_name} = Rules.get_rule!(rule_id)

    payload =
      implementation
      |> Map.take([:implementation_key, :rule_id, :domain_id])
      |> Map.put(:rule_name, rule_name)

    # TODO: TD-4455 What about other fields that have changed?
    # Why do we need an implementation_moved event instead of using a
    # generic implementation_updated event?

    publish("implementation_moved", "implementation", id, user_id, payload)
  end

  def implementation_updated(
        _repo,
        %{implementation: %{id: id}},
        %{changes: %{df_content: _df_content}} = changeset,
        user_id
      ) do
    # TODO: TD-4455 Why do we need an implementation_changed event instead of
    # using a generic implementation_updated? What about other fields that have
    # changed? Should domain_id be included?
    publish("implementation_changed", "implementation", id, user_id, changeset)
  end

  def implementation_updated(
        _repo,
        %{implementation: %{id: id} = implementation},
        _changeset,
        user_id
      ) do
    payload = Map.take(implementation, [:implementation_key, :rule_id, :domain_id])
    # TODO: TD-4455 Why aren't any changes included in the payload
    publish("implementation_updated", "implementation", id, user_id, payload)
  end

  @doc """
  Publishes `:rule_result_created` events.  Should be called using `Ecto.Multi.run/5`.
  """
  def rule_results_created(_repo, %{results: results}, user_id) do
    results
    |> Enum.map(&rule_result_created(&1, user_id))
    |> publish()
  end

  defp rule_result_created(%{id: id} = payload, user_id) do
    domain_ids = domain_ids(payload)

    payload =
      payload
      |> Map.put(:domain_ids, domain_ids)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{
      event: "rule_result_created",
      resource_type: "rule_result",
      resource_id: id,
      user_id: user_id,
      payload: payload
    }
  end

  defp domain_ids(%{domain_id: domain_id}) do
    TaxonomyCache.get_parent_ids(domain_id)
  end

  defp domain_ids(%{business_concept_id: business_concept_id}) do
    case ConceptCache.get(business_concept_id, :domain_ids) do
      {:ok, domain_ids} when domain_ids != [] -> domain_ids
      _ -> nil
    end
  end

  defp domain_ids(_), do: nil
end
