defmodule TdDq.Canada.RuleAbilities do
  @moduledoc false
  alias Ecto.Changeset
  alias TdCache.ConceptCache
  alias TdDq.Auth.Claims
  alias TdDq.Permissions
  alias TdDq.Rules.Rule

  # Service account can view all rules
  def can?(%Claims{role: "service"}, :show, %Rule{}), do: true

  def can?(%Claims{} = claims, :show, %Rule{
        business_concept_id: business_concept_id,
        domain_id: domain_id
      }) do
    Permissions.authorized?(claims, :view_quality_rule, domain_id) &&
      authorized?(claims, business_concept_id)
  end

  def can?(%Claims{} = claims, :update, %Changeset{} = changeset) do
    domain_ids = fetch_values(changeset, :domain_id)
    business_concept_ids = fetch_values(changeset, :business_concept_id)

    Enum.all?(domain_ids, &Permissions.authorized?(claims, :manage_quality_rule, &1)) &&
      Enum.all?(business_concept_ids, &authorized?(claims, &1))
  end

  def can?(%Claims{} = claims, action, %Changeset{} = changeset)
      when action in [:create, :delete] do
    domain_id = Changeset.fetch_field!(changeset, :domain_id)
    business_concept_id = Changeset.fetch_field!(changeset, :business_concept_id)

    Permissions.authorized?(claims, :manage_quality_rule, domain_id) &&
      authorized?(claims, business_concept_id)
  end

  def can?(%Claims{} = claims, :manage, Rule) do
    Permissions.authorized?(claims, :manage_quality_rule)
  end

  def can?(%Claims{} = claims, :create_implementation, %Rule{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_quality_rule_implementations, domain_id)
  end

  def can?(%Claims{}, _action, _entity), do: false

  defp fetch_values(%Changeset{data: %Rule{} = data} = changeset, field)
       when field in [:domain_id, :business_concept_id] do
    case Changeset.fetch_field(changeset, field) do
      {:data, value} -> [value]
      {:changes, value} -> [Map.get(data, field), value]
    end
  end

  defp authorized?(_claims, nil), do: true

  defp authorized?(%Claims{} = claims, business_concept_id) do
    {:ok, status} = ConceptCache.member_confidential_ids(business_concept_id)

    case status do
      1 ->
        Permissions.authorized?(
          claims,
          :manage_confidential_business_concepts,
          business_concept_id
        )

      _ ->
        true
    end
  end
end
