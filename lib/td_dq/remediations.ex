defmodule TdDq.Remediations do
  @moduledoc """
  The Remediations context.
  """

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.Audit
  alias Truedat.Auth.Claims

  def get_remediation(id) do
    Repo.get_by(Remediation, id: id)
  end

  def create_remediation(rule_result_id, params, %Claims{user_id: user_id}) do
    changeset = params
    |> Map.put("rule_result_id", rule_result_id)
    |> Remediation.changeset()

    Multi.new()
    |> Multi.insert(:remediation, changeset)
    |> Multi.run(:audit, Audit, :remediation_created, [changeset, user_id])
    |> Repo.transaction()
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
