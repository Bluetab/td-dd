defmodule TdDq.Implementations.Policy do
  @moduledoc "Authorization rules for quality implementations"

  alias Ecto.Changeset
  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  @workflow_actions [:delete, :edit, :move, :execute, :publish, :restore, :reject, :submit]
  @media_actions [
    :auto_publish,
    "execute",
    "create",
    "createBasic",
    "createBasicRuleLess",
    "createRaw",
    "createRawRuleLess",
    "createRuleLess",
    "download",
    "upload",
    "uploadResults"
  ]

  def authorize(:query, %{role: "admin"}, _params), do: true
  def authorize(:query, %{role: "service"}, _params), do: true

  def authorize(:reindex, %{role: "admin"}, _params), do: true

  def authorize(:query, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:mutation, %{role: "admin"}, _params), do: true

  def authorize(:mutation, %{role: "user"} = claims, :publish_implementation),
    do: Permissions.authorized?(claims, :publish_implementation)

  def authorize(:mutation, %{role: "user"} = claims, :restore_implementation),
    do: Permissions.authorized?(claims, :publish_implementation)

  def authorize(:mutation, %{role: "user"} = claims, :reject_implementation),
    do: Permissions.authorized?(claims, :publish_implementation)

  def authorize(:mutation, %{role: "user"} = claims, :submit_implementation) do
    Permissions.authorized_any?(claims, [
      :manage_ruleless_implementations,
      :manage_quality_rule_implementations,
      :manage_raw_quality_rule_implementations
    ])
  end

  def authorize(action, %{role: "admin"}, _params) when action in @media_actions, do: true

  def authorize("execute", %{} = claims, _params),
    do: Permissions.authorized?(claims, :execute_quality_rule_implementations)

  def authorize(:auto_publish, %{} = claims, _params) do
    Permissions.authorized?(claims, :publish_implementation)
  end

  def authorize("create", %{} = claims, _params),
    do: Permissions.authorized?(claims, :manage_quality_rule_implementations)

  def authorize("createBasic", %{} = claims, _params),
    do: Permissions.authorized?(claims, :manage_basic_implementations)

  def authorize("createBasicRuleLess", %{} = claims, _params),
    do:
      Permissions.authorized?(claims, [
        :manage_basic_implementations,
        :manage_ruleless_implementations
      ])

  def authorize("createRaw", %{} = claims, _params),
    do: Permissions.authorized?(claims, :manage_raw_quality_rule_implementations)

  def authorize("createRawRuleLess", %{} = claims, _params),
    do:
      Permissions.authorized?(claims, [
        :manage_raw_quality_rule_implementations,
        :manage_ruleless_implementations
      ])

  def authorize("createRuleLess", %{} = claims, _params),
    do:
      Permissions.authorized?(claims, [
        :manage_quality_rule_implementations,
        :manage_ruleless_implementations
      ])

  def authorize("download", %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize("upload", %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize("uploadResults", %{} = claims, _params),
    do: Permissions.authorized?(claims, :manage_rule_results)

  def authorize(action, %{role: "admin"}, %Changeset{})
      when action in [:create, :delete, :update, :move, :clone, :publish],
      do: true

  def authorize(action, %{} = claims, %Changeset{} = changeset)
      when action in [:create, :delete, :update, :publish] do
    domain_id = Changeset.fetch_field!(changeset, :domain_id)
    Enum.all?(permissions(changeset), &Permissions.authorized?(claims, &1, domain_id))
  end

  def authorize(:view, %{role: role} = claims, %Implementation{domain_id: domain_id}) do
    role in ["admin", "service"] or
      Permissions.authorized?(claims, :view_quality_rule, domain_id)
  end

  def authorize(:manage_rule_results, %{role: role} = claims, %Implementation{
        domain_id: domain_id
      }) do
    role in ["admin", "service"] or
      Permissions.authorized?(claims, :manage_rule_results, domain_id)
  end

  def authorize(:link_concept, %{role: role} = claims, %Implementation{domain_id: domain_id}) do
    role == "admin" or
      Permissions.authorized?(claims, :link_implementation_business_concept, domain_id)
  end

  def authorize(:link_structure, %{role: role} = claims, %Implementation{domain_id: domain_id}) do
    role == "admin" or Permissions.authorized?(claims, :link_implementation_structure, domain_id)
  end

  def authorize(action, %{role: "admin"}, %Implementation{} = implementation)
      when action in @workflow_actions do
    valid_action?(action, implementation)
  end

  def authorize(
        :delete,
        %{} = claims,
        %Implementation{domain_id: domain_id, status: :published} = implementation
      ) do
    valid_action?(:delete, implementation) and
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  def authorize(:delete, %{} = claims, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:delete, implementation) and
      Enum.all?(permissions(implementation), &Permissions.authorized?(claims, &1, domain_id))
  end

  def authorize(:edit, %{} = claims, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:edit, implementation) and
      Enum.all?(permissions(implementation), &Permissions.authorized?(claims, &1, domain_id))
  end

  def authorize(
        :manage_segments,
        %{} = claims,
        %Implementation{domain_id: domain_id} = implementation
      ) do
    authorize(:edit, claims, implementation) and
      Permissions.authorized?(claims, :manage_segments, domain_id)
  end

  def authorize(:submit, %{} = claims, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:submit, implementation) and
      Enum.all?(permissions(implementation), &Permissions.authorized?(claims, &1, domain_id))
  end

  def authorize(:clone, %{role: "admin"}, %Implementation{}), do: true

  def authorize(:clone, %{} = claims, %Implementation{domain_id: domain_id} = implementation) do
    Enum.all?(permissions(implementation), &Permissions.authorized?(claims, &1, domain_id))
  end

  def authorize(action, %{} = claims, %Implementation{domain_id: domain_id} = implementation)
      when action in [:publish, :reject, :restore] do
    valid_action?(action, implementation)  and
      Permissions.authorized?(claims, :publish_implementation, domain_id)
  end

  # Service accounts can execute rule implementations
  def authorize(:execute, %{role: "service"}, _), do: true

  def authorize(:execute, %{} = claims, %Implementation{domain_id: domain_id} = implementation) do
    valid_action?(:execute, implementation) &&
      Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def authorize(:execute, %{} = claims, %{domain_ids: [domain_id | _]}) do
    Permissions.authorized?(claims, :execute_quality_rule_implementations, domain_id)
  end

  def authorize(:view_published_concept, %{role: role} = claims, domain_id) do
    role == "admin" or
      Permissions.authorized?(claims, :view_published_business_concepts, domain_id)
  end

  def authorize(_action, _claims, _params), do: false

  defp valid_action?(:delete, %{status: :published} = imp), do: Implementation.versionable?(imp)
  defp valid_action?(:edit, %{status: :published} = imp), do: Implementation.versionable?(imp)
  defp valid_action?(:delete, imp), do: Implementation.deletable?(imp)
  defp valid_action?(:edit, imp), do: Implementation.editable?(imp)
  defp valid_action?(:execute, imp), do: Implementation.executable?(imp)
  defp valid_action?(:publish, imp), do: Implementation.publishable?(imp)
  defp valid_action?(:restore, imp), do: Implementation.restorable?(imp)
  defp valid_action?(:reject, imp), do: Implementation.rejectable?(imp)
  defp valid_action?(:submit, imp), do: Implementation.submittable?(imp)
  defp valid_action?(:move, imp), do: valid_action?(:edit, imp)

  defp permissions(%Changeset{} = changeset) do
    perms =
      changeset
      |> Changeset.apply_changes()
      |> permissions()

    perms = case Changeset.fetch_change(changeset, :segments) do
      :error -> perms
      {:ok, _} -> [:manage_segments | perms]
    end
    case Changeset.fetch_change(changeset, :status) do
      :error -> perms
      {:ok, :published} -> [:publish_implementation | perms]
      {:ok, _} -> perms
    end
  end

  defp permissions(%Implementation{} = impl) do
    impl
    |> Map.take([:rule_id, :segments, :implementation_type, :status])
    |> Enum.flat_map(fn
      {:implementation_type, "raw"} -> [:manage_raw_quality_rule_implementations]
      {:implementation_type, "basic"} -> [:manage_basic_implementations]
      {:implementation_type, "default"} -> [:manage_quality_rule_implementations]
      {:rule_id, nil} -> [:manage_ruleless_implementations]
      {:segments, [_ | _]} -> [:manage_segments]
      _ -> []
    end)
  end
end
