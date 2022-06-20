defmodule TdDq.Canada.ImplementationAbilities do
  @moduledoc false

  alias Ecto.Changeset
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  @workflow_actions [:delete, :edit, :move, :execute, :publish, :reject, :submit]

  @mutation_permissions %{
    submit_implementation: [
      :manage_ruleless_implementations,
      :manage_quality_rule_implementations,
      :manage_raw_quality_rule_implementations
    ],
    reject_implementation: [:publish_implementation],
    publish_implementation: [:publish_implementation]
  }

  @action_permissions %{
    "execute" => :execute_quality_rule_implementations,
    "create" => [:manage_quality_rule_implementations],
    "createRaw" => [:manage_raw_quality_rule_implementations],
    "createRawRuleLess" => [
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations
    ],
    "createRuleLess" => [:manage_quality_rule_implementations, :manage_ruleless_implementations],
    "download" => :view_quality_rule,
    "upload" => :view_quality_rule,
    "uploadResults" => :manage_rule_results
  }

  # GraphQL mutation authorizations
  def can?(%{role: "admin"}, :mutation, _mutation), do: true
  def can?(%{role: "service"}, :mutation, _mutation), do: false

  def can?(%{role: "user"} = claims, :mutation, mutation) do
    case Map.get(@mutation_permissions, mutation) do
      nil -> false
      permissions -> Permissions.authorized_any?(claims, permissions)
    end
  end

  # TODO: maybe some of these can be removed? manage_implementations, manage_raw_implementations, ...
  def can?(%{role: "service"}, :manage_quality_rule_implementations, Implementation), do: false

  def can?(%{role: "admin"}, _action, Implementation), do: true

  # Actions in implementation search results
  def can?(claims, action, Implementation)
      when action in [
             "execute",
             "create",
             "createRaw",
             "createRawRuleLess",
             "createRuleLess",
             "download",
             "upload",
             "uploadResults"
           ] do
    permission_or_permissions = Map.fetch!(@action_permissions, action)

    Permissions.authorized?(claims, permission_or_permissions)
  end

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

  # Workflow actions have preconditions even for admin accounts
  def can?(%{role: "admin"}, action, %Implementation{} = implementation)
      when action in @workflow_actions do
    valid_action?(action, implementation)
  end

  def can?(%{role: "admin"}, :clone, %Implementation{}), do: true

  # Any other action can be performed by an admin account
  def can?(%{role: "admin"}, _action, _target), do: true

  def can?(%{} = claims, :submit, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:submit, implementation) &&
      Enum.all?(
        permissions(implementation),
        &Permissions.authorized?(claims, &1, domain_id)
      )
  end

  def can?(%{} = claims, :reject, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:reject, implementation) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def can?(%{} = claims, :publish, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:publish, implementation) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def can?(
        %{} = claims,
        :delete,
        %Implementation{domain_id: domain_id, status: :published} = implementation
      ) do
    valid_action?(:delete, implementation) &&
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def can?(
        %{} = claims,
        :delete,
        %Implementation{domain_id: domain_id} = implementation
      ) do
    valid_action?(:delete, implementation) &&
      Enum.all?(
        permissions(implementation),
        &Permissions.authorized?(claims, &1, domain_id)
      )
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

  def can?(%{} = claims, :manage_segments, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:edit, implementation) &&
      Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def can?(%{} = claims, :edit, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:edit, implementation) &&
      Enum.all?(
        permissions(implementation),
        &Permissions.authorized?(claims, &1, domain_id)
      )
  end

  def can?(%{} = claims, :edit_segments, %Changeset{changes: %{segments: _}} = changeset) do
    domain_id = domain_id(changeset)
    Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  ## TODO: avoid give permissions by default
  def can?(%{}, :edit_segments, %Changeset{}), do: true

  def can?(%{} = claims, :edit_segments, %Implementation{domain_id: domain_id, segments: segments})
      when length(segments) !== 0 do
    Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def can?(%{} = claims, :edit_segments, %Implementation{} = implementation) do
    can?(claims, :edit, implementation)
  end

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

  def can?(%{} = claims, action, %Changeset{} = changeset)
      when action in [:create, :delete, :update] do
    Permissions.authorized?(claims, permission(changeset), domain_id(changeset))
  end

  # Service accounts can execute rule implementations
  def can?(%{role: "service"}, :execute, _), do: true

  def can?(%{} = claims, :execute, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:execute, implementation) &&
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

  defp permission(%Changeset{} = changeset) do
    changeset
    |> Changeset.fetch_field!(:implementation_type)
    |> permission_by_type()
  end

  defp permissions(%Implementation{
         rule_id: rule_id,
         segments: segments,
         implementation_type: type
       }) do
    [
      permission_by_type(type),
      permission_by_rule_id(rule_id),
      permission_by_segments(segments)
    ]
    |> List.flatten()
  end

  defp permission_by_type("raw"), do: :manage_raw_quality_rule_implementations
  defp permission_by_type("default"), do: :manage_quality_rule_implementations
  defp permission_by_type("draft"), do: :manage_quality_rule_implementations
  defp permission_by_rule_id(nil), do: :manage_ruleless_implementations
  defp permission_by_rule_id(_), do: []
  defp permission_by_segments([]), do: []
  defp permission_by_segments([_ | _]), do: :manage_segments

  defp valid_action?(:delete, %{status: :published} = implementation),
    do: Implementation.versionable?(implementation)

  defp valid_action?(:delete, implementation), do: Implementation.deletable?(implementation)

  defp valid_action?(:edit, %{status: :published} = implementation),
    do: Implementation.versionable?(implementation)

  defp valid_action?(:edit, implementation), do: Implementation.editable?(implementation)
  defp valid_action?(:execute, implementation), do: Implementation.executable?(implementation)
  defp valid_action?(:publish, implementation), do: Implementation.publishable?(implementation)
  defp valid_action?(:reject, implementation), do: Implementation.rejectable?(implementation)
  defp valid_action?(:submit, implementation), do: Implementation.submittable?(implementation)
  defp valid_action?(:move, implementation), do: valid_action?(:edit, implementation)
end
