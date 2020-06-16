defmodule TdDd.DataStructures.BulkUpdateTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo
  alias TdDdWeb.ApiServices.MockTdAuthService

  @valid_content %{"string" => "present", "list" => "one"}
  @valid_params %{"df_content" => @valid_content}

  setup_all do
    start_supervised(MockTdAuthService)

    %{id: template_id, name: type} = template = build(:template)
    TemplateCache.put(template, publish: false)

    on_exit(fn ->
      TemplateCache.delete(template_id)
    end)

    [type: type]
  end

  describe "update_all/3" do
    test "update all data structures with valid data", %{type: type} do
      user = build(:user)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} = BulkUpdate.update_all(ids, @valid_params, user)
      assert Map.keys(updates) <|> ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))
    end

    test "emits audit events for updated structures", %{type: type} do
      user = build(:user)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates, audit: audit}} = BulkUpdate.update_all(ids, @valid_params, user)
      assert Enum.count(audit) == Enum.count(updates)
    end

    test "ignores unchanged data structures", %{type: type} do
      %{id: user_id} = user = build(:user)

      ids =
        1..10
        |> Enum.map(fn
          n when n > 5 -> valid_structure(type, df_content: @valid_content, last_change_by: 99)
          _ -> valid_structure(type)
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} = BulkUpdate.update_all(ids, @valid_params, user)

      structures = Enum.map(ids, &Repo.get(DataStructure, &1))

      assert structures
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert %{99 => unchanged_ids, ^user_id => changed_ids} =
               Enum.group_by(structures, & &1.last_change_by, & &1.id)

      assert Enum.count(unchanged_ids) == 5
      assert Enum.count(changed_ids) == 5
      assert Map.keys(updates) <|> changed_ids
    end

    test "returns an error if a structure has no template", %{type: type} do
      user = build(:user)

      ids =
        1..10
        |> Enum.map(fn
          9 -> invalid_structure()
          _ -> valid_structure(type)
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:error, :updates, changeset, _changes_so_far} =
               BulkUpdate.update_all(ids, @valid_params, user)

      assert %{data: data, errors: errors} = changeset
      assert %{external_id: "the bad one"} = data
      assert {"invalid template", _} = errors[:df_content]
    end

    test "only updates specified fields", %{type: type} do
      user = build(:user)

      initial_content = Map.replace!(@valid_content, "string", "initial")

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} =
               BulkUpdate.update_all(ids, %{"df_content" => %{"string" => "updated"}}, user)

      assert Map.keys(updates) <|> ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == %{"string" => "updated", "list" => initial_content["list"]}))
    end

    test "ignores empty fields", %{type: type} do
      user = build(:user)

      initial_content = Map.replace!(@valid_content, "string", "initial")

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => "", "list" => "two"}},
                 user
               )

      assert Map.keys(updates) <|> ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == %{"string" => initial_content["string"], "list" => "two"}))
    end
  end

  defp invalid_structure do
    insert(:data_structure_version,
      type: "missing_type",
      data_structure: build(:data_structure, external_id: "the bad one")
    )
  end

  defp valid_structure(type, ds_opts \\ []) do
    insert(:data_structure_version,
      type: type,
      data_structure: build(:data_structure, ds_opts)
    )
  end
end
