defmodule TdDq.CSV.ImplementationsReaderTest do
  use TdDd.DataCase

  alias TdDq.CSV.ImplementationsReader
  alias TdDq.Implementations.Implementation

  @user_content [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "default" => %{"value" => "", "origin" => "user"},
          "label" => "User",
          "name" => "data_owner",
          "type" => "user",
          "values" => %{"processed_users" => [], "role_users" => "Data Owner"},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "default" => %{"value" => "", "origin" => "user"},
          "label" => "User list",
          "name" => "data_owner_multiple",
          "type" => "user",
          "values" => %{"processed_users" => [], "role_users" => "Data Owner"},
          "widget" => "dropdown"
        }
      ]
    }
  ]

  setup context do
    claims = build(:claims)

    if path = context[:fixture] do
      stream = File.stream!("test/fixtures/implementations/" <> path, [:trim_bom])

      [stream: stream, claims: claims]
    else
      [claims: claims]
    end
  end

  describe "CSV.Reader" do
    @tag fixture: "implementations.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 return ok with records", %{stream: stream, claims: claims} do
      CacheHelpers.insert_template(name: "bar_template")

      insert(:rule, name: "rule_foo")

      assert {:ok, %{ids: _ids, errors: []}} =
               ImplementationsReader.read_csv(claims, stream, false, "en")
    end

    @tag fixture: "implementations_malformed.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 return errors with invalid csv", %{stream: stream, claims: claims} do
      assert {:error, error} = ImplementationsReader.read_csv(claims, stream, false, "en")

      assert error == %{
               error: :missing_required_columns,
               expected: "implementation_key, result_type, goal, minimum",
               found: "with_no_required_headers, foo, bar"
             }
    end

    @tag fixture: "implementations_user_field.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 creates implementation with valid user field", %{
      stream: stream,
      claims: claims
    } do
      domain = CacheHelpers.insert_domain(external_id: "domain_external_id")
      insert(:rule, name: "rule_foo", domain_id: domain.id)
      user = CacheHelpers.insert_user(full_name: "user")
      user1 = CacheHelpers.insert_user(full_name: "user1")
      user2 = CacheHelpers.insert_user(full_name: "user2")

      CacheHelpers.insert_acl(domain.id, "Data Owner", [user.id, user1.id, user2.id])
      CacheHelpers.insert_template(name: "bar_template", content: @user_content)

      {:ok, %{errors: [], ids: [id], ids_to_reindex: [_]}} =
        ImplementationsReader.read_csv(claims, stream, false, "en")

      assert Repo.get!(Implementation, id).df_content == %{
               "data_owner" => %{"origin" => "file", "value" => user.full_name},
               "data_owner_multiple" => %{
                 "origin" => "file",
                 "value" => [user1.full_name, user2.full_name]
               }
             }
    end

    @tag fixture: "implementations_invalid_user_field.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 return errors having record with invalid user field", %{
      stream: stream,
      claims: claims
    } do
      domain = CacheHelpers.insert_domain(external_id: "domain_external_id")
      insert(:rule, name: "rule_foo", domain_id: domain.id)
      user = CacheHelpers.insert_user(full_name: "user")
      CacheHelpers.insert_acl(domain.id, "Data Owner", [user.id])
      CacheHelpers.insert_template(name: "bar_template", content: @user_content)

      {:ok, %{errors: errors, ids: [], ids_to_reindex: []}} =
        ImplementationsReader.read_csv(claims, stream, false, "en")

      assert errors == [
               %{
                 implementation_key: "foo_key_1",
                 message: %{df_content: ["data_owner: is invalid"]}
               }
             ]
    end
  end
end
