defmodule TdDq.Rules.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Repo
  alias TdDq.Implementations.Implementation
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule

  @stream TdCache.Audit.stream()

  setup do
    on_exit(fn -> Redix.del!(@stream) end)
    %{id: domain_id} = CacheHelpers.insert_domain()
    %{name: template_name} = CacheHelpers.insert_template(scope: "dq")
    claims = build(:claims, role: "admin")

    rule =
      insert(:rule, df_name: template_name, domain_id: domain_id, df_content: %{"bar" => "foo"})

    implementation = insert(:implementation, rule: rule, deleted_at: nil, domain_id: domain_id)

    [
      claims: claims,
      rule: rule,
      implementation: implementation,
      template_name: template_name
    ]
  end

  describe "rule_created/4" do
    test "publishes an event", %{claims: %{user_id: user_id}, rule: rule} do
      %{
        id: rule_id,
        domain_id: domain_id,
        name: name,
        df_content: content,
        description: description,
        business_concept_id: business_concept_id
      } = rule

      changeset = Rule.changeset(rule, %{})

      assert {:ok, event_id} =
               Audit.rule_created(
                 Repo,
                 %{rule: rule},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      domain_ids = [domain_id]
      user_id = "#{user_id}"
      resource_id = "#{rule_id}"

      assert %{
               event: "rule_created",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "rule",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "name" => ^name,
               "domain_id" => ^domain_id,
               "domain_ids" => ^domain_ids,
               "content" => ^content,
               "description" => ^description,
               "business_concept_id" => ^business_concept_id
             } = Jason.decode!(payload)
    end
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
      %{
        id: implementation_id,
        implementation_key: implementation_key,
        rule_id: rule_id,
        domain_id: domain_id
      } = implementation

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

      domain_ids = [domain_id]

      assert %{
               "implementation_key" => ^implementation_key,
               "rule_id" => ^rule_id,
               "domain_id" => ^domain_id,
               "domain_ids" => ^domain_ids
             } = Jason.decode!(payload)
    end
  end

  describe "implementation_deleted/4" do
    test "publishes implementation_deleted", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{
        id: implementation_id,
        implementation_key: implementation_key,
        rule_id: rule_id,
        domain_id: domain_id
      } = implementation

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
               "rule_id" => ^rule_id,
               "domain_id" => ^domain_id
             } = Jason.decode!(payload)
    end
  end

  describe "implementation_updated/4" do
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
      rule: rule,
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{
        id: implementation_id,
        rule_id: rule_id,
        domain_id: domain_id
      } = implementation

      child_implementation =
        insert(
          :implementation,
          rule: rule,
          implementation_ref: implementation_id,
          domain_id: domain_id
        )

      implementations_moved = [implementation, child_implementation]

      changeset = %{changes: %{rule_id: rule_id}}

      assert {:ok, event_ids} =
               Audit.implementation_updated(
                 Repo,
                 %{implementations_moved: {2, implementations_moved}},
                 changeset,
                 user_id
               )

      event_ids
      |> Enum.with_index()
      |> Enum.each(fn {event_id, i} ->
        assert {:ok, [event]} =
                 Stream.range(:redix, @stream, event_id, event_id, transform: :range)

        user_id = "#{user_id}"

        %{id: resource_id, implementation_key: implementation_key} =
          implementations_moved
          |> Enum.at(i)
          |> Map.take([:id, :implementation_key])

        resource_id = "#{resource_id}"

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
                 "rule_id" => ^rule_id,
                 "domain_id" => ^domain_id,
                 "rule_name" => _
               } = Jason.decode!(payload)
      end)
    end
  end

  describe "implementations_deprecated/2" do
    test "publishes implementation_status_updated with deprecated status", %{
      implementation: implementation
    } do
      %{
        id: implementation_id,
        implementation_key: implementation_key,
        rule_id: rule_id,
        domain_id: domain_id
      } = implementation

      assert {:ok, [event_id]} =
               Audit.implementations_deprecated(Repo, %{deprecated: {1, [implementation]}})

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      resource_id = "#{implementation_id}"

      assert %{
               event: "implementation_status_updated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "implementation",
               service: "td_dd",
               ts: _ts,
               user_id: "0"
             } = event

      assert %{
               "implementation_key" => ^implementation_key,
               "status" => "deprecated",
               "rule_id" => ^rule_id,
               "domain_id" => ^domain_id
             } = Jason.decode!(payload)
    end
  end

  describe "remediation_created/4" do
    test "publishes remediation_created", %{
      implementation: implementation,
      claims: %{user_id: user_id}
    } do
      %{
        id: rule_result_id,
        date: date,
        implementation: %{
          id: implementation_id,
          implementation_key: implementation_key,
          domain_id: domain_id
        }
      } = rule_result = insert(:rule_result, implementation: implementation)

      %{
        id: id,
        df_content: df_content
      } =
        remediation =
        insert(:remediation, rule_result: rule_result, df_content: %{"foo" => "bar"})

      changeset = Remediation.changeset(remediation, %{})

      assert {:ok, event_id} =
               Audit.remediation_created(
                 Repo,
                 %{remediation: remediation},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{id}"

      assert %{
               event: "remediation_created",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "remediation",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      domain_ids = [domain_id]

      date_string =
        date
        |> DateTime.to_date()
        |> Date.to_iso8601()

      assert %{
               "implementation_key" => ^implementation_key,
               "domain_ids" => ^domain_ids,
               "content" => ^df_content,
               "date" => ^date_string,
               "rule_result_id" => ^rule_result_id,
               "implementation_id" => ^implementation_id
             } = Jason.decode!(payload)
    end
  end
end
