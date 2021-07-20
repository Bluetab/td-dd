defmodule TdDd.GrantsTest do
  use TdDd.DataCase
  import TdDd.TestOperators

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Grants

  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
  end

  describe "grants" do
    alias TdDd.Grants.Grant

    @valid_attrs %{
      detail: %{},
      end_date: "2010-04-17T14:00:00.000000Z",
      start_date: "2010-04-17T14:00:00.000000Z",
      user_id: 42
    }
    @update_attrs %{
      detail: %{},
      end_date: "2011-05-18T15:01:01.000000Z",
      start_date: "2011-05-18T15:01:01.000000Z",
      user_id: 43
    }
    @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

    test "list_grants/0 returns all grants" do
      grant = insert(:grant)
      assert Grants.list_grants() <|> [grant]
    end

    test "get_grant!/1 returns the grant with given id" do
      grant = insert(:grant)
      assert Grants.get_grant!(grant.id) <~> grant
    end

    test "get_grant!/1 returns the grant preloaded structure" do
      grant = insert(:grant)
      refute Grants.get_grant!(grant.id) == grant
      assert Grants.get_grant!(grant.id, preload: [data_structure: [:system]]) == grant
    end

    test "create_grant/3 with valid data creates a grant" do
      claims = build(:claims)
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{} = grant
              }} = Grants.create_grant(@valid_attrs, data_structure, claims)

      date_value = DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")
      assert grant.detail == %{}
      assert grant.end_date == date_value
      assert grant.start_date == date_value
      assert grant.user_id == 42
      assert grant.data_structure_id == data_structure_id

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      date_string_value = Map.get(@valid_attrs, :end_date)

      assert %{
               "detail" => %{},
               "end_date" => ^date_string_value,
               "start_date" => ^date_string_value,
               "user_id" => 42,
               "data_structure_id" => ^data_structure_id
             } = Jason.decode!(payload)
    end

    test "create_grant/3 with invalid data returns error changeset" do
      claims = build(:claims)
      data_structure = insert(:data_structure)

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.create_grant(@invalid_attrs, data_structure, claims)
    end

    test "update_grant/2 with valid data updates the grant" do
      claims = build(:claims)
      %{user_id: previous_user_id} = grant = insert(:grant)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{} = grant
              }} = Grants.update_grant(grant, @update_attrs, claims)

      assert grant.detail == %{}
      assert grant.end_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.start_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.user_id == previous_user_id

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      date_string_value = Map.get(@update_attrs, :end_date)

      assert %{
               "detail" => %{},
               "end_date" => ^date_string_value,
               "start_date" => ^date_string_value
             } = Jason.decode!(payload)
    end

    test "update_grant/2 with invalid data returns error changeset" do
      claims = build(:claims)
      grant = insert(:grant)

      assert {:error, :grant, %Ecto.Changeset{}, _} =
               Grants.update_grant(grant, @invalid_attrs, claims)

      assert grant <~> Grants.get_grant!(grant.id)
    end

    test "delete_grant/1 deletes the grant" do
      claims = build(:claims)
      grant = insert(:grant)

      assert {:ok,
              %{
                audit: event_id,
                grant: %Grant{}
              }} = Grants.delete_grant(grant, claims)

      assert {:ok, [%{id: ^event_id, payload: "{}"}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant!(grant.id) end
    end
  end
end
