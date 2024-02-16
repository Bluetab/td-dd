defmodule TdDq.Remediations do
  @moduledoc """
  The Remediations context.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.Audit
  alias Truedat.Auth.Claims

  @pagination_params [:order_by, :limit, :before, :after]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def list_remediations(clauses \\ %{}) do
    clauses
    |> remediations_query
    |> Repo.all()
  end

  def remediations_query(params) do
    Enum.reduce(params, Remediation, fn
      {:filters, filters}, q ->
        Enum.reduce(filters, q, fn
          {:inserted_since, inserted_since}, q ->
            where(q, [remediation], remediation.inserted_at >= ^inserted_since)

          {:updated_since, updated_since}, q ->
            where(q, [remediation], remediation.updated_at >= ^updated_since)
        end)

      {:id, id}, q ->
        where(q, [r], r.id == ^id)

      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:order_by, order}, q ->
        order_by(q, ^order)

      {:limit, lim}, q ->
        limit(q, ^lim)

      {:before, id}, q ->
        where(q, [r], r.id < type(^id, :integer))

      {:after, id}, q ->
        where(q, [r], r.id > type(^id, :integer))

      _, q ->
        q
    end)
  end

  def get_remediation(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    %{id: id, preload: preloads}
    |> remediations_query()
    |> Repo.one()
  end

  def create_remediation(rule_result_id, params, %Claims{user_id: user_id}) do
    changeset =
      params
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

  def min_max_count(params) do
    params
    |> Map.drop(@pagination_params)
    |> remediations_query()
    |> select([r], %{count: count(r), min_id: min(r.id), max_id: max(r.id)})
    |> Repo.one()
  end
end
