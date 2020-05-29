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
    test "update alls data structure with valid data", %{type: type} do
      user = build(:user)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, updated_ids} = BulkUpdate.update_all(ids, @valid_params, user)
      assert ids <|> updated_ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))
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

      assert {:ok, updated_ids} = BulkUpdate.update_all(ids, @valid_params, user)

      structures = Enum.map(ids, &Repo.get(DataStructure, &1))

      assert structures
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert %{99 => unchanged_ids, ^user_id => changed_ids} =
               Enum.group_by(structures, & &1.last_change_by, & &1.id)

      assert Enum.count(unchanged_ids) == 5
      assert Enum.count(changed_ids) == 5
      assert changed_ids <|> updated_ids
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

      assert {:error, changeset} = BulkUpdate.update_all(ids, @valid_params, user)
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

      assert {:ok, updated_ids} =
               BulkUpdate.update_all(ids, %{"df_content" => %{"string" => "updated"}}, user)

      assert ids <|> updated_ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == %{"string" => "updated", "list" => initial_content["list"]}))
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
