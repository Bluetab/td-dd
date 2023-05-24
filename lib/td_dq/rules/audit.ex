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
  alias TdDq.Rules.RuleResults

  @doc """
  Publishes a `:rule_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_created(_repo, %{rule: %{id: id} = rule}, %{} = _changeset, user_id) do
    payload =
      rule
      |> with_domain_ids()
      |> with_df_content()
      |> Map.take([
        :name,
        :df_name,
        :domain_id,
        :domain_ids,
        :content,
        :description,
        :business_concept_id
      ])

    publish("rule_created", "rule", id, user_id, payload)
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
    rule_name = implementation_rule_name(rule_id)

    payload =
      implementation
      |> with_domain_ids()
      |> Map.take([:implementation_key, :rule_id, :domain_id, :domain_ids])
      |> Map.put(:rule_name, rule_name)

    publish("implementation_created", "implementation", id, user_id, payload)
  end

  defp implementation_rule_name(nil), do: nil

  defp implementation_rule_name(rule_id) do
    %{name: rule_name} = Rules.get_rule!(rule_id)
    rule_name
  end

  @doc """
  Publishes `:implementation_deprecated` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementation_deprecated(repo, payload, changeset, user_id) do
    implementation_deleted(repo, payload, changeset, user_id, "implementation_deprecated")
  end

  @doc """
  Publishes `:implementation_deleted` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementation_deleted(
        _repo,
        %{implementation: %{id: id} = implementation},
        _changeset,
        user_id,
        event \\ "implementation_deleted"
      ) do
    implementation
    |> make_implementation_deleted_payload
    |> then(fn payload ->
      publish(event, "implementation", id, user_id, payload)
    end)
  end

  @doc """
  Publishes a list of `:implementation_deleted` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementations_deleted(_repo, %{implementations: {_, implementations}}, user_id)
      when is_list(implementations) do
    implementations
    |> Enum.map(fn %{id: id} = implementation ->
      implementation
      |> make_implementation_deleted_payload
      |> then(fn payload ->
        %{
          event: "implementation_deleted",
          resource_type: "implementation",
          resource_id: id,
          user_id: user_id,
          payload: payload
        }
      end)
    end)
    |> publish
  end

  defp make_implementation_deleted_payload(implementation) do
    implementation
    |> with_domain_ids()
    |> Map.take([:implementation_key, :rule_id, :domain_id, :domain_ids])
  end

  @doc """
  Publishes `:implementations_deprecated` events. Should be called using `Ecto.Multi.run/5`.
  """
  def implementations_deprecated(_repo, %{deprecated: {_, [_ | _] = impls}}) do
    impls
    |> Enum.map(fn %{id: id} = implementation ->
      payload =
        implementation
        |> with_domain_ids()
        |> Map.take([:implementation_key, :rule_id, :domain_id, :domain_ids])
        |> Map.put(:status, :deprecated)

      publish("implementation_status_updated", "implementation", id, 0, payload)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: event_ids} -> {:ok, event_ids}
    end
  end

  def implementations_deprecated(_repo, _), do: {:ok, []}

  def implementations_deleted(_repo, _), do: {:ok, []}

  @doc """
  Publishes an `implementation_updated` event (or `implementation_deprecated`,
  `implementation_restored`, `implementation_moved`, `implementation_changed`).
  Should be called using `Ecto.Multi.run/5`.
  """
  def implementation_updated(repo, implementation, changeset, user_id)

  def implementation_updated(
        _repo,
        %{implementations_moved: {_, implementations}},
        %{changes: %{rule_id: rule_id}},
        user_id
      ) do
    %{name: rule_name} = Rules.get_rule!(rule_id)

    implementations
    |> Enum.map(fn %{id: id} = implementation ->
      payload =
        implementation
        |> Map.take([:implementation_key, :rule_id, :domain_id])
        |> Map.put(:rule_name, rule_name)

      %{
        event: "implementation_moved",
        resource_type: "implementation",
        resource_id: id,
        user_id: user_id,
        payload: payload
      }
    end)
    |> publish
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
    payload =
      implementation
      |> with_domain_ids()
      |> Map.take([:implementation_key, :rule_id, :domain_id, :domain_ids])

    # TODO: TD-4455 Why aren't any changes included in the payload
    publish("implementation_updated", "implementation", id, user_id, payload)
  end

  def implementation_versioned(_repo, %{versioned: {_, [id | _]}}, implementation, user_id) do
    payload =
      implementation
      |> with_domain_ids()
      |> Map.take([:implementation_key, :rule_id, :domain_id, :domain_ids])
      |> Map.put(:status, :versioned)

    publish("implementation_status_updated", "implementation", id, user_id, payload)
  end

  def implementation_versioned(_repo, _, _implementation, _user_id) do
    {:ok, :unchanged}
  end

  def implementation_status_updated(
        _repo,
        %{implementation: %{id: id} = implementation},
        %{changes: %{status: status}},
        user_id
      ) do
    payload =
      implementation
      |> with_domain_ids()
      |> Map.take([:implementation_key, :domain_ids])
      |> Map.put(:status, status)

    publish("implementation_status_updated", "implementation", id, user_id, payload)
  end

  def implementation_status_updated(_repo, _implementation, _changeset, _user_id) do
    {:ok, :unchanged}
  end

  @doc """
  Publishes `:rule_result_created` events.  Should be called using `Ecto.Multi.run/5`.
  """
  def rule_results_created(_repo, %{results: results}, user_id) do
    results
    |> Enum.map(&rule_result_created(&1, user_id))
    |> publish()
  end

  defp rule_result_created(%{implementation_ref: implementation_ref} = payload, user_id) do
    payload =
      payload
      |> with_domain_ids()
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{
      event: "rule_result_created",
      resource_type: "rule_result",
      resource_id: implementation_ref,
      user_id: user_id,
      payload: payload
    }
  end

  @doc """
  Publishes an `:remediation_created` event. Should be called using
  `Ecto.Multi.run/5`.
  """
  def remediation_created(
        _repo,
        %{remediation: %{id: id, rule_result_id: rule_result_id}},
        _changeset,
        user_id
      ) do
    %{
      id: rule_result_id,
      date: date,
      implementation:
        %{implementation_key: implementation_key, id: implementation_id} = implementation
    } = RuleResults.get_rule_result(rule_result_id, preload: [:implementation])

    domain_ids = get_domain_ids(implementation)

    payload =
      Map.new(
        date: date,
        domain_ids: domain_ids,
        implementation_key: implementation_key,
        implementation_id: implementation_id,
        rule_result_id: rule_result_id
      )

    publish("remediation_created", "remediation", id, user_id, payload)
  end

  defp with_domain_ids(payload) do
    Map.put(payload, :domain_ids, get_domain_ids(payload))
  end

  defp get_domain_ids(%{domain_id: domain_id}) do
    TaxonomyCache.reaching_domain_ids(domain_id)
  end

  defp get_domain_ids(%{business_concept_id: business_concept_id}) do
    case ConceptCache.get(business_concept_id, :domain_ids) do
      {:ok, domain_ids} when domain_ids != [] -> domain_ids
      _ -> nil
    end
  end

  defp get_domain_ids(_), do: nil

  defp with_df_content(%{df_content: content} = payload) do
    Map.put(payload, :content, content)
  end

  defp with_df_content(payload), do: payload
end
