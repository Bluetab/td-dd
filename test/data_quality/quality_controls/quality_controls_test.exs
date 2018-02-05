defmodule DataQuality.QualityControlsTest do
  use DataQuality.DataCase

  alias DataQuality.QualityControls

  describe "quality_controls" do
    alias DataQuality.QualityControls.QualityControl

    @valid_attrs %{business_concept_id: "some business_concept_id", description: "some description", goal: 42, minimum: 42, name: "some name", population: "some population", priority: "some priority", type: "some type", weight: 42}
    @update_attrs %{business_concept_id: "some updated business_concept_id", description: "some updated description", goal: 43, minimum: 43, name: "some updated name", population: "some updated population", priority: "some updated priority", type: "some updated type", weight: 43}
    @invalid_attrs %{business_concept_id: nil, description: nil, goal: nil, minimum: nil, name: nil, population: nil, priority: nil, type: nil, weight: nil}

    def quality_control_fixture(attrs \\ %{}) do
      {:ok, quality_control} =
        attrs
        |> Enum.into(@valid_attrs)
        |> QualityControls.create_quality_control()

      quality_control
    end

    test "list_quality_controls/0 returns all quality_controls" do
      quality_control = quality_control_fixture()
      assert QualityControls.list_quality_controls() == [quality_control]
    end

    test "get_quality_control!/1 returns the quality_control with given id" do
      quality_control = quality_control_fixture()
      assert QualityControls.get_quality_control!(quality_control.id) == quality_control
    end

    test "create_quality_control/1 with valid data creates a quality_control" do
      assert {:ok, %QualityControl{} = quality_control} = QualityControls.create_quality_control(@valid_attrs)
      assert quality_control.business_concept_id == "some business_concept_id"
      assert quality_control.description == "some description"
      assert quality_control.goal == 42
      assert quality_control.minimum == 42
      assert quality_control.name == "some name"
      assert quality_control.population == "some population"
      assert quality_control.priority == "some priority"
      assert quality_control.type == "some type"
      assert quality_control.weight == 42
    end

    test "create_quality_control/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = QualityControls.create_quality_control(@invalid_attrs)
    end

    test "update_quality_control/2 with valid data updates the quality_control" do
      quality_control = quality_control_fixture()
      assert {:ok, quality_control} = QualityControls.update_quality_control(quality_control, @update_attrs)
      assert %QualityControl{} = quality_control
      assert quality_control.business_concept_id == "some updated business_concept_id"
      assert quality_control.description == "some updated description"
      assert quality_control.goal == 43
      assert quality_control.minimum == 43
      assert quality_control.name == "some updated name"
      assert quality_control.population == "some updated population"
      assert quality_control.priority == "some updated priority"
      assert quality_control.type == "some updated type"
      assert quality_control.weight == 43
    end

    test "update_quality_control/2 with invalid data returns error changeset" do
      quality_control = quality_control_fixture()
      assert {:error, %Ecto.Changeset{}} = QualityControls.update_quality_control(quality_control, @invalid_attrs)
      assert quality_control == QualityControls.get_quality_control!(quality_control.id)
    end

    test "delete_quality_control/1 deletes the quality_control" do
      quality_control = quality_control_fixture()
      assert {:ok, %QualityControl{}} = QualityControls.delete_quality_control(quality_control)
      assert_raise Ecto.NoResultsError, fn -> QualityControls.get_quality_control!(quality_control.id) end
    end

    test "change_quality_control/1 returns a quality_control changeset" do
      quality_control = quality_control_fixture()
      assert %Ecto.Changeset{} = QualityControls.change_quality_control(quality_control)
    end
  end
end
