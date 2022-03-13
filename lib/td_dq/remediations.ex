defmodule TdDq.Remediations do
  @moduledoc """
  The Remediations context.
  """

  alias TdDd.Repo
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.RuleResult

  def get_remediation(id) do
    Repo.get_by(Remediation, id: id)
  end

  def get_by_rule_result_id(rule_result_id) do
    %RuleResult{remediation: remediation} =
      Repo.get(RuleResult, rule_result_id)
      |> Repo.preload([:remediation, :rule, :implementation])
    remediation
  end

  def create_remediation(rule_result_id, params) do
    Map.put(params, "rule_result_id", rule_result_id)
    |> Remediation.changeset()
    |> Repo.insert()
  end

  def update_remediation(remediation, params) do
    remediation
    |> Remediation.changeset(params)
    |> Repo.update()
  end

  def delete_remediation(%Remediation{} = remediation) do
    Repo.delete(remediation)
  end
end
