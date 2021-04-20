defmodule TdDq.Rules.AuditTest do
  use TdDq.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.TemplateCache
  alias TdDd.Repo
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  @stream TdCache.Audit.stream()

  setup_all do
    %{id: template_id, name: template_name} = template = build(:template)
    TemplateCache.put(template, publish: false)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      Redix.del!(@stream)
    end)

    [template_name: template_name]
  end

  setup %{template_name: template_name} do
    on_exit(fn -> Redix.del!(@stream) end)

    claims = build(:claims, role: "admin")
    rule = insert(:rule, df_name: template_name)
    implementation = insert(:implementation, rule: rule, deleted_at: nil)
    [claims: claims, rule: rule, implementation: implementation]
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

      assert %{
               "content" => _content,
               "name" => "new name"
             } = Jason.decode!(payload)
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

  describe "implementation_updated/4" do
    test "publishes on soft deletion", %{
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
               user_id: ""
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id
             } = Jason.decode!(payload)
    end
  end
end
