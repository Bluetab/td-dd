defmodule TdDd.DataStructures.ProfileTest do
  use TdDd.DataCase

  alias TdDd.Profiles.Profile
  alias TdDd.Repo

  @value %{
    "null_count" => "1.0",
    "most_frequent" => ~s([["A", "76"], ["B", "1.0"], ["C", "-41"]]),
    "total_count" => "1.0"
  }

  describe "Profile.changeset/1" do
    test "casts valid parameters, expanding value" do
      params = %{"data_structure_id" => 123, "value" => @value}
      assert %{valid?: true, changes: changes} = Profile.changeset(params)
      assert %{most_frequent: _, null_count: _, total_count: _, value: _} = changes
    end

    test "return an insertable changeset" do
      %{id: id} = insert(:data_structure)

      assert {:ok, profile} =
               %{"data_structure_id" => id, "value" => @value}
               |> Profile.changeset()
               |> Repo.insert()

      assert %{
               most_frequent: [
                 %{"k" => "A", "v" => 76},
                 %{"k" => "B", "v" => 1},
                 %{"k" => "C", "v" => -41}
               ],
               null_count: 1,
               total_count: 1,
               value: @value
             } = profile
    end
  end
end
