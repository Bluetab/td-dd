defmodule TdDd.DataStructures.MetadataViewTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.MetadataView

  describe "MetadataView.changeset/2" do
    test "validates required fields" do
      assert %{valid?: false, errors: errors} =
               MetadataView.changeset(%MetadataView{}, %{fields: nil})

      assert errors[:name]
      assert errors[:fields]
    end

    test "validates fields is an array" do
      assert %{valid?: false, errors: errors} =
               MetadataView.changeset(%MetadataView{}, %{name: "foo", fields: "*"})

      assert {_, [type: {:array, :string}, validation: :cast]} = errors[:fields]
    end

    test "accepts an empty array" do
      assert %{valid?: true} = MetadataView.changeset(%MetadataView{}, %{name: "foo", fields: []})
    end
  end
end
