defmodule TdDq.Rules.Policy do
  @moduledoc "Authorization rules for quality rules"

  @behaviour Bodyguard.Policy

  alias Ecto.Changeset
  alias TdCache.ConceptCache
  alias TdDq.Rules.Rule

  import TdDq.Permissions, only: [authorized?: 2, authorized?: 3]

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(:view, %{role: "service"}, _params), do: true

  def authorize(:manage_quality_rule, %{} = claims, _params) do
    authorized?(claims, :manage_quality_rule)
  end

  def authorize(:view, %{} = claims, %Rule{business_concept_id: concept_id, domain_id: domain_id}) do
    authorized?(claims, :view_quality_rule, domain_id) and
      maybe_authorize_confidential(claims, concept_id)
  end

  def authorize(action, %{} = claims, %Changeset{} = changeset)
      when action in [:create, :delete] do
    domain_id = Changeset.fetch_field!(changeset, :domain_id)
    business_concept_id = Changeset.fetch_field!(changeset, :business_concept_id)

    authorized?(claims, :manage_quality_rule, domain_id) and
      maybe_authorize_confidential(claims, business_concept_id)
  end

  def authorize(:update, %{} = claims, %Changeset{} = changeset) do
    domain_ids = fetch_values(changeset, :domain_id)
    business_concept_ids = fetch_values(changeset, :business_concept_id)

    Enum.all?(domain_ids, &authorized?(claims, :manage_quality_rule, &1)) and
      Enum.all?(business_concept_ids, &maybe_authorize_confidential(claims, &1))
  end

  def authorize(:upsert, %{} = _claims, %{
        "domain_id" => domain_id,
        "business_concept_id" => business_concept_id
      })
      when not is_nil(domain_id) and not is_nil(business_concept_id) do
    case ConceptCache.get(business_concept_id) do
      {:ok, %{shared_to_ids: shared_to_ids, domain: %{id: bc_domain_id}}} ->
        [bc_domain_id | shared_to_ids]
        |> Enum.uniq()
        |> Enum.member?(domain_id)

      {:ok, nil} ->
        true
    end
  end

  def authorize(:upsert, %{}, %{} = _params), do: true

  def authorize(_action, _claims, _params), do: false

  defp maybe_authorize_confidential(_claims, nil), do: true

  defp maybe_authorize_confidential(%{} = claims, concept_id) do
    case ConceptCache.member_confidential_ids(concept_id) do
      {:ok, 1} -> check_authorize_confidential_domain_ids(claims, concept_id)
      _ -> true
    end
  end

  defp check_authorize_confidential_domain_ids(claims, concept_id) do
    concept_domain_ids =
      case ConceptCache.get(concept_id) do
        {:ok, %{shared_to_ids: shared_to_ids, domain: %{id: bc_domain_id}}} ->
          [bc_domain_id | shared_to_ids]
          |> Enum.uniq()

        {:ok, nil} ->
          []
      end

    authorized?(claims, :manage_confidential_business_concepts, concept_domain_ids)
  end

  defp fetch_values(%Changeset{data: %Rule{} = data} = changeset, field)
       when field in [:domain_id, :business_concept_id] do
    case Changeset.fetch_field(changeset, field) do
      {:data, value} -> [value]
      {:changes, value} -> [Map.get(data, field), value]
    end
  end
end
