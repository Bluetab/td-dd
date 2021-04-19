defmodule TdDq.Rules.RuleResults do
  @moduledoc """
  The Rule Results context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDq.Cache.RuleLoader
  alias TdDq.Executions.Execution
  alias TdDq.Repo
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  require Logger

  @index_worker Application.compile_env(:td_dq, :index_worker)

  def get_rule_result(id) do
    Repo.get_by(RuleResult, id: id)
  end

  def list_rule_results do
    RuleResult
    |> join(:inner, [rr, ri], ri in Implementation,
      on: rr.implementation_key == ri.implementation_key
    )
    |> join(:inner, [_, ri, r], r in Rule, on: r.id == ri.rule_id)
    |> where([_, _, r], is_nil(r.deleted_at))
    |> where([_, ri, _], is_nil(ri.deleted_at))
    |> Repo.all()
  end

  @doc """
  Creates a rule_result.

  ## Examples

      iex> create_rule_result(%{field: value})
      {:ok, %{result: RuleResult{}}}

      iex> create_rule_result(%{field: bad_value})
      {:error, failed_operation, failed_value, changes_so_far}

  """
  def create_rule_result(%Implementation{implementation_key: key} = impl, params \\ %{}) do
    %{rule: %{result_type: result_type}} = Repo.preload(impl, :rule)

    changeset =
      RuleResult.changeset(%RuleResult{implementation_key: key, result_type: result_type}, params)

    Multi.new()
    |> Multi.insert(:result, changeset)
    |> Multi.run(:executions, fn _repo, %{result: result} ->
      res = update_executions(result)
      {:ok, res}
    end)
    |> Repo.transaction()
    |> on_create()
  end

  defp update_executions(%{id: id, implementation_key: key, inserted_at: ts} = _result) do
    Execution
    |> select([e], e)
    |> where([e], is_nil(e.result_id))
    |> join(:inner, [e], i in assoc(e, :implementation))
    |> where([e, i], i.implementation_key == ^key)
    |> update(set: [result_id: ^id, updated_at: ^ts])
    |> Repo.update_all([])
  end

  defp on_create({:ok, %{result: rule_result}} = result) do
    %{
      rule: %{id: rule_id},
      implementation: %{id: implementation_id}
    } = Repo.preload(rule_result, [:implementation, :rule])

    @index_worker.reindex_rules(rule_id)
    @index_worker.reindex_implementations(implementation_id)

    result
  end

  defp on_create(result), do: result

  @doc """
  Returns last rule_result for each active implementation of rule
  """
  def get_latest_rule_results(%Rule{} = rule) do
    rule
    |> Repo.preload(:rule_implementations)
    |> Map.get(:rule_implementations)
    |> Enum.filter(&is_nil(Map.get(&1, :deleted_at)))
    |> Enum.map(&get_latest_rule_result(&1.implementation_key))
    |> Enum.filter(& &1)
  end

  def get_latest_rule_result(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> join(:inner, [r, ri], ri in Implementation,
      on: r.implementation_key == ri.implementation_key
    )
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  def get_implementation_results(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> order_by(desc: :date)
    |> Repo.all()
  end

  def delete_rule_result(%RuleResult{} = rule_result) do
    %{rule: rule} = Repo.preload(rule_result, :rule)

    rule_result
    |> Repo.delete()
    |> refresh_on_delete(rule)

    # TODO: Audit event?
  end

  defp refresh_on_delete({:ok, _} = res, %{id: rule_id}) do
    RuleLoader.refresh(rule_id)
    res
  end

  defp refresh_on_delete(res, _), do: res
end
