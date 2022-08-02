defmodule TdDd.GrantsTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Grants
  alias TdDd.Grants.Grant

  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
  end

  setup do
    %{id: user_id, user_name: user_name} = user = CacheHelpers.insert_user()
    %{id: data_structure_id} = data_structure = insert(:data_structure)

    [
      user: user,
      user_id: user_id,
      user_name: user_name,
      claims: build(:claims),
      data_structure: data_structure,
      data_structure_id: data_structure_id
    ]
  end

  describe "get_grant!/1" do
    test "returns the grant with given id" do
      %{id: id} = grant = insert(:grant)
      assert Grants.get_grant!(id) <~> grant
    end

    test "returns the grant preloaded structure" do
      %{id: id} = insert(:grant)

      assert %{data_structure: %{system: %{id: _}}, id: ^id} =
               Grants.get_grant!(id, preload: [data_structure: :system])
    end
  end

  describe "create_grant/3" do
    test "with valid data creates a grant", %{
      claims: claims,
      user_id: user_id,
      user_name: user_name,
      data_structure: data_structure,
      data_structure_id: data_structure_id
    } do
      params = %{
        detail: %{},
        end_date: "2010-04-17",
        start_date: "2010-04-17",
        user_name: user_name,
        source_user_name: user_name
      }

      assert {:ok, %{grant: %Grant{} = grant}} =
               Grants.create_grant(params, data_structure, claims)

      assert %{
               detail: %{},
               end_date: ~D[2010-04-17],
               start_date: ~D[2010-04-17],
               user_id: ^user_id,
               data_structure_id: ^data_structure_id,
               source_user_name: ^user_name
             } = grant
    end

    test "source_user_name is required", %{
      claims: claims,
      data_structure: data_structure
    } do
      params =
        :grant
        |> string_params_for(data_structure_id: data_structure.id, user_id: claims.user_id)
        |> Map.drop(["source_user_name"])

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {"can't be blank", [validation: :required]} = errors[:source_user_name]
    end

    test "publishes an audit event", %{
      claims: claims,
      user_id: user_id,
      data_structure: data_structure
    } do
      params = %{
        detail: %{},
        end_date: "2010-04-17",
        start_date: "2010-04-17",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:ok, %{audit: event_id, grant: grant}} =
               Grants.create_grant(params, data_structure, claims)

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_created",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert resource_id == to_string(grant.id)
      assert audit_user_id == to_string(claims.user_id)

      assert %{
               "detail" => %{},
               "end_date" => "2010-04-17",
               "start_date" => "2010-04-17",
               "user_id" => ^user_id
             } = Jason.decode!(payload)
    end

    test "will not allow a start date to be greater than the end_date", %{
      claims: claims,
      data_structure: data_structure,
      user_id: user_id
    } do
      params = %{
        end_date: "2010-04-10",
        start_date: "2010-04-20",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [constraint: :check, constraint_name: "date_range"]} = errors[:end_date]
    end

    test "will not allow two grants of same structure and user on the same period",
         %{user_id: user_id, data_structure: data_structure, claims: claims} do
      params = %{
        end_date: "2010-04-20",
        start_date: "2010-04-16",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-18",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [{:constraint, :exclusion}, {:constraint_name, "no_overlap"}]} = errors[:user_id]

      params = %{
        start_date: "2010-04-15",
        end_date: "2010-04-19",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(params, data_structure, claims)

      assert {_, [{:constraint, :exclusion}, {:constraint_name, "no_overlap"}]} = errors[:user_id]
    end

    test "will allow two grants of same structure and user on different periods",
         %{claims: claims, data_structure: data_structure, user_id: user_id} do
      params = %{
        end_date: "2010-04-20",
        start_date: "2010-04-16",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)

      params = %{
        start_date: "2010-04-21",
        end_date: "2010-04-26",
        user_id: user_id,
        source_user_name: "source_user_name"
      }

      assert {:ok, _} = Grants.create_grant(params, data_structure, claims)
    end

    test "with invalid data returns error changeset", %{
      claims: claims,
      data_structure: data_structure
    } do
      invalid_params = %{start_date: nil}

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.create_grant(invalid_params, data_structure, claims)

      assert {_, [validation: :required]} = errors[:start_date]
    end
  end

  describe "update_grant/3" do
    test "with valid data updates the grant", %{claims: claims} do
      grant = insert(:grant)

      params = %{
        detail: %{},
        end_date: "2011-05-18",
        start_date: "2011-05-18",
        source_user_name: "source_user_name"
      }

      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)

      assert %{
               detail: detail,
               end_date: ~D[2011-05-18],
               start_date: ~D[2011-05-18]
             } = grant

      assert detail == %{}
    end

    test "request_removal of a grant with user_id", %{claims: claims} do
      grant = insert(:grant, user_id: 123)

      params = %{pending_removal: true}

      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)
      assert %{pending_removal: true} = grant
    end

    test "request_removal of a grant with source_user_name but not user_id", %{claims: claims} do
      grant = insert(:grant, source_user_name: "test_source_user_name")

      params = %{
        pending_removal: true
      }

      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)
      assert %{pending_removal: true} = grant
    end

    test "does not change user_id", %{claims: claims, user_id: new_user_id} do
      %{user_id: user_id} = grant = insert(:grant, user_id: 123)
      params = %{user_id: new_user_id}
      assert new_user_id != user_id
      assert {:ok, %{grant: grant}} = Grants.update_grant(grant, params, claims)
      assert %{user_id: ^user_id} = grant
    end

    test "publishes an audit event", %{claims: claims, user_id: user_id} do
      %{id: id} = grant = insert(:grant, user_id: 123)

      params = %{
        detail: %{},
        end_date: "2011-05-18",
        start_date: "2011-05-18",
        user_id: user_id
      }

      assert {:ok, %{audit: event_id}} = Grants.update_grant(grant, params, claims)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_updated",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert audit_user_id == to_string(claims.user_id)
      assert resource_id == to_string(id)

      assert Jason.decode!(payload) == %{
               "detail" => %{},
               "end_date" => "2011-05-18",
               "start_date" => "2011-05-18"
             }
    end

    test "with invalid data returns error changeset", %{claims: claims} do
      grant = insert(:grant)

      invalid_params = %{start_date: nil, user_id: nil}

      assert {:error, :grant, %{errors: errors}, _} =
               Grants.update_grant(grant, invalid_params, claims)

      assert {_, [validation: :required]} = errors[:start_date]
    end
  end

  describe "delete_grant/1" do
    test "deletes the grant", %{claims: claims} do
      %{id: id} = grant = insert(:grant)

      assert {:ok, %{grant: %Grant{}}} = Grants.delete_grant(grant, claims)

      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant!(id) end
    end

    test "publishes an audit event", %{
      claims: claims
    } do
      %{id: id, data_structure_id: data_structure_id, user_id: user_id} = grant = insert(:grant)

      assert {:ok, %{audit: event_id}} = Grants.delete_grant(grant, claims)
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               event: "grant_deleted",
               id: ^event_id,
               payload: payload,
               resource_id: resource_id,
               resource_type: "grant",
               user_id: audit_user_id
             } = event

      assert audit_user_id == to_string(claims.user_id)
      assert resource_id == to_string(id)

      assert %{
               "data_structure_id" => ^data_structure_id,
               "domain_ids" => [],
               "end_date" => "2021-02-03",
               "resource" => %{},
               "start_date" => "2020-01-02",
               "user_id" => ^user_id
             } = Jason.decode!(payload)
    end
  end
end
