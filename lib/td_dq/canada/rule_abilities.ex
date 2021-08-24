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

  def can?(%Claims{} = claims, action, %Changeset{} = changeset)
      when action in [:create, :delete, :update] do
    domain_id = Changeset.fetch_field!(changeset, :domain_id)
    business_concept_id = Changeset.fetch_field!(changeset, :business_concept_id)

    Permissions.authorized?(claims, :manage_quality_rule, domain_id) &&
      authorized?(claims, business_concept_id)
  end

  def can?(%Claims{} = claims, :manage, Rule) do
    Permissions.authorized?(claims, :manage_quality_rule)
  end

  def can?(%Claims{}, _action, _entity), do: false

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
