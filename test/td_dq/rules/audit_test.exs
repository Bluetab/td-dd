defmodule TdDq.Rules.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule

  @stream TdCache.Audit.stream()

  setup do
    on_exit(fn -> Redix.del!(@stream) end)
    domain_id = System.unique_integer([:positive])
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    claims = build(:dq_claims, role: "admin")
    rule = insert(:rule, df_name: template_name, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule, deleted_at: nil, domain_id: domain_id)
    [claims: claims, rule: rule, implementation: implementation, template_name: template_name]
  end

  describe "rule_updated/4" do
    test "publishes an event", %{rule: rule, claims: %{user_id: user_id}} do
      %{id: rule_id} = rule

      params = %{df_content: %{"list" => "two"}, name: "new name"}
      changeset = Rule.changeset(rule, params)

      assert {:ok, event_id} = Audit.rule_updated(Repo, %{rule: rule}, changeset, user_id)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{rule_id}"

      assert %{
               event: "rule_updated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "rule",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{"content" => _, "name" => "new name"} = Jason.decode!(payload)
    end
  end

  describe "rule_deleted/3" do
    test "publishes an event", %{claims: %{user_id: user_id}} do
      %{id: rule_id} = rule = insert(:rule)

      assert {:ok, event_id} = Audit.rule_deleted(Repo, %{rule: rule}, user_id)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{rule_id}"

      assert %{
               event: "rule_deleted",
               payload: "{}",
               resource_id: ^resource_id,
               resource_type: "rule",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event
    end
  end

  describe "implementation_created/4" do
    test "publishes implementation_created", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      changeset = Implementation.changeset(implementation, %{})

      assert {:ok, event_id} =
               Audit.implementation_created(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_created",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{"implementation_key" => ^implementation_key, "rule_id" => ^rule_id} =
               Jason.decode!(payload)
    end
  end

  describe "implementation_deleted/4" do
    test "publishes implementation_deleted", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      {:ok, changeset} =
        implementation
        |> Implementation.changeset(%{})
        |> Repo.delete()

      assert {:ok, event_id} =
               Audit.implementation_deleted(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_deleted",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end
  end

  describe "implementation_updated/4" do
    test "publishes implementation_deprecated on soft deletion", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      params = %{deleted_at: DateTime.utc_now()}
      changeset = Implementation.changeset(implementation, params)

      assert {:ok, event_id} =
               Audit.implementation_updated(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_deprecated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end

    test "publishes implementation_restored on soft deletion undo", %{
      rule: rule,
      claims: %{user_id: user_id}
    } do
      implementation = insert(:implementation, rule: rule, deleted_at: DateTime.utc_now())

      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      params = %{deleted_at: nil}
      changeset = Implementation.changeset(implementation, params)

      assert {:ok, event_id} =
               Audit.implementation_updated(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_restored",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end

    test "publishes implementation_updated with df_content", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{id: implementation_id} = implementation

      df_content = %{
        "new_field1" => "foo",
        "new_field2" => "bar"
      }

      params = %{df_content: df_content}
      changeset = Implementation.changeset(implementation, params)

      assert {:ok, event_id} =
               Audit.implementation_updated(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_changed",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "df_content" => %{"added" => ^df_content}
             } = Jason.decode!(payload)
    end

    test "publishes implementation_moved", %{
      implementation: implementation,
      claims: %{user_id: user_id},
      template_name: template_name
    } do
      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      %{id: new_rule_id} = insert(:rule, df_name: template_name)
      params = %{rule_id: new_rule_id}
      changeset = Implementation.changeset(implementation, params)

      assert {:ok, event_id} =
               Audit.implementation_updated(
                 Repo,
                 %{implementation: implementation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      user_id = "#{user_id}"
      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_moved",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end
  end

  describe "implementations_deprecated/2" do
    test "publishes implementation_deprecated event", %{implementation: implementation} do
      %{id: implementation_id, implementation_key: implementation_key, rule_id: rule_id} =
        implementation

      assert {:ok, [event_id]} =
               Audit.implementations_deprecated(Repo, %{deprecated: {1, [implementation]}})

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_deprecated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: "0"
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end
  end
end
