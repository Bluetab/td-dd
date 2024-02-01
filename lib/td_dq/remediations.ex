defmodule TdDq.Remediations do
  @moduledoc """
  The Remediations context.
  """

  alias TdDd.Repo
  alias TdDq.Remediations.Remediation

  def get_remediation(id) do
    Repo.get_by(Remediation, id: id)
  end

  def create_remediation(rule_result_id, params) do
    params
    |> Map.put("rule_result_id", rule_result_id)
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
