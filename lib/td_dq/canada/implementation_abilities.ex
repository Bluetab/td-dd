defmodule TdDq.Canada.ImplementationAbilities do
  @moduledoc false

  alias Ecto.Changeset
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  def can?(%{role: "service"}, :manage_implementations, Implementation), do: false

  def can?(%{role: "admin"}, _action, _resource), do: true

  def can?(%{} = claims, :manage_implementations, Implementation) do
    Permissions.authorized?(claims, :manage_quality_rule_implementations)
  end

  def can?(%{role: "service"}, :manage_raw_implementations, Implementation), do: false

  def can?(%{} = claims, :manage_raw_implementations, Implementation) do
    Permissions.authorized?(claims, :manage_raw_quality_rule_implementations)
  end

  def can?(%{role: "service"}, :manage_ruleless_implementations, Implementation), do: false

  def can?(%{} = claims, :manage_ruleless_implementations, Implementation) do
    Permissions.authorized?(claims, :manage_ruleless_implementations)
  end

  # Service accounts can do anything but manage Implementations
  def can?(%{role: "service"}, _action, _target), do: true

  def can?(%{} = claims, :list, Implementation) do
    Permissions.authorized?(claims, :view_quality_rule)
  end

  def can?(
        %{} = claims,
        :manage_draft_implementation,
        %Implementation{domain_id: domain_id} = impl
      ) do
    Implementation.is_updatable?(impl) &&
      Permissions.authorized?(claims, :manage_draft_implementation, domain_id)
  end

  def can?(%{} = claims, :send_for_approval, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_updatable?(impl) &&
      Permissions.authorized?(claims, :manage_draft_implementation, domain_id)
  end

  def can?(%{} = claims, :send_for_approval, Implementation) do
    Permissions.authorized?(claims, :manage_draft_implementation)
  end

  def can?(%{} = claims, :reject, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_rejectable?(impl) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def can?(%{} = claims, :reject, Implementation) do
    Permissions.authorized?(claims, :publish_implementation)
  end

  def can?(%{} = claims, :unreject, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_undo_rejectable?(impl) &&
      Permissions.authorized?(claims, :manage_draft_implementation, domain_id)
  end

  def can?(%{} = claims, :unreject, Implementation) do
    Permissions.authorized?(claims, :manage_draft_implementation)
  end

  def can?(%{} = claims, :publish, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_publishable?(impl) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def can?(%{} = claims, :publish, Implementation) do
    Permissions.authorized?(claims, :publish_implementation)
  end

  def can?(%{} = claims, :deprecate, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_deprecatable?(impl) &&
      Permissions.authorized?(claims, :deprecate_implementation, domain_id)
  end

  def can?(%{} = claims, :deprecate, Implementation) do
    Permissions.authorized?(claims, :deprecate_implementation)
  end

  def can?(%{} = claims, :publish_from_draft, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_updatable?(impl) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id) &&
      Permissions.authorized?(claims, :manage_draft_implementation, domain_id)
  end

  def can?(%{} = claims, :publish_from_draft, Implementation) do
    Permissions.authorized?(claims, :publish_implementation) &&
      Permissions.authorized?(claims, :manage_draft_implementation)
  end

  def can?(%{} = claims, :delete, %Implementation{domain_id: domain_id} = impl) do
    Implementation.is_deletable?(impl) &&
      Permissions.authorized?(claims, :manage_draft_implementation, domain_id)
  end

  def can?(%{} = claims, :show, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :view_quality_rule, domain_id)
  end

  def can?(%{} = claims, :link_concept, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :link_implementation_business_concept, domain_id)
  end

  def can?(%{} = claims, :link_structure, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :link_implementation_structure, domain_id)
  end

  def can?(%{} = claims, :manage_segments, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def can?(%{} = claims, :edit, implementation) do
    Enum.all?(
      [:edit_segments, :manage_ruleless_implementations, :manage, :manage_draft_implementation],
      &can?(claims, &1, implementation)
    )
  end

  def can?(%{} = claims, :edit_segments, %Changeset{changes: %{segments: _}} = changeset) do
    domain_id = domain_id(changeset)
    Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def can?(%{}, :edit_segments, %Changeset{}), do: true

  def can?(%{} = claims, :edit_segments, %Implementation{domain_id: domain_id, segments: segments})
      when length(segments) !== 0 do
    Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def can?(%{}, :edit_segments, %Implementation{}), do: true

  def can?(%{}, :create_ruleless_implementations, %Changeset{changes: %{rule_id: rule_id}})
      when not is_nil(rule_id),
      do: true

  def can?(%{} = claims, :create_ruleless_implementations, %Changeset{
        changes: %{domain_id: domain_id}
      }) do
    Permissions.authorized?(claims, :manage_ruleless_implementations, domain_id)
  end

  def can?(%{}, :create_ruleless_implementations, %Changeset{}), do: false

  def can?(
        %{} = claims,
        :manage_ruleless_implementations,
        %Implementation{domain_id: domain_id, rule_id: nil}
      ) do
    Permissions.authorized?(claims, :manage_ruleless_implementations, domain_id)
  end

  def can?(%{}, :manage_ruleless_implementations, %Implementation{}), do: true

  def can?(%{} = claims, :manage, %Implementation{domain_id: domain_id} = implementation) do
    permission = permission(implementation)
    Permissions.authorized?(claims, permission, domain_id)
  end

  def can?(%{} = claims, action, %Changeset{} = changeset)
      when action in [:create, :delete, :update] do
    domain_id = domain_id(changeset)
    permission = permission(changeset)
    Permissions.authorized?(claims, permission, domain_id)
  end

  # Service accounts can execute rule implementations
  def can?(%{role: "service"}, :execute, _), do: true

  def can?(%{} = claims, :execute, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(%{} = claims, :execute, %{domain_ids: [domain_id | _]}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def can?(%{} = claims, :manage_rule_results, %Implementation{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_rule_results, domain_id)
  end

  def can?(_claims, _action, _resource), do: false

  defp domain_id(%{domain_id: domain_id}), do: domain_id

  defp domain_id(%Changeset{data: %{domain_id: domain_id}}) when not is_nil(domain_id),
    do: domain_id

  defp domain_id(%Changeset{} = changeset), do: Changeset.fetch_field!(changeset, :domain_id)

  defp permission("raw"), do: :manage_raw_quality_rule_implementations
  defp permission("default"), do: :manage_quality_rule_implementations
  defp permission("draft"), do: :manage_quality_rule_implementations
  defp permission(%Implementation{implementation_type: type}), do: permission(type)

  defp permission(%Changeset{} = changeset) do
    changeset
    |> Changeset.fetch_field!(:implementation_type)
    |> permission()
  end
end
