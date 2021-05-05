defmodule TdDd.ClassifiersTest do
  use TdDd.DataCase

  alias TdDd.Classifiers
  alias TdDd.Classifiers.Classifier
  alias TdDd.Repo

  setup do
    %{id: system_id} = system = insert(:system)
    [system: system, system_id: system_id]
  end

  describe "Classifiers.create_classifier/1" do
    test "creates a classifier", %{system_id: system_id} do
      params = %{
        "system_id" => system_id,
        "name" => "environment",
        "filters" => [
          %{"path" => ["type"], "values" => ["schema"]}
        ],
        "rules" => [
          %{
            "class" => "prod",
            "path" => ["external_id"],
            "regex" => "glue://.*"
          },
          %{
            "class" => "dev",
            "priority" => 10,
            "path" => ["metadata", "foo", "bar"],
            "values" => ["whatever", "whatever"]
          }
        ]
      }

      assert {:ok, %{classifier: classifier}} = Classifiers.create_classifier(params)

      assert %{
               filters: [filter],
               rules: [r1, r2],
               name: "environment"
             } = classifier

      assert %{path: ["type"], values: ["schema"]} = filter

      assert %{
               id: _,
               priority: 0,
               class: "prod",
               path: ["external_id"],
               regex: ~r/glue:\/\/.*/
             } = r1

      assert %{
               id: _,
               priority: 10,
               class: "dev",
               path: ["metadata", "foo", "bar"],
               values: ["whatever"]
             } = r2
    end

    test "classifies existing data structures" do
      %{id: dsv_id, data_structure: %{system_id: system_id}} =
        insert(:data_structure_version, type: "foo")

      params = %{
        "system_id" => system_id,
        "name" => "environment",
        "rules" => [
          %{"class" => "foo", "path" => ["type"], "regex" => "^foo$"}
        ]
      }

      assert {:ok, %{classifications: classifications}} = Classifiers.create_classifier(params, returning: true)
      assert %{"foo" => {_, [classification]}} = classifications
      assert %{data_structure_version_id: ^dsv_id} = classification
    end
  end

  describe "Classifiers.delete_classifier/2" do
    test "deletes a classifier" do
      classifier = insert(:classifier)
      assert {:ok, %{__meta__: meta}} = Classifiers.delete_classifier(classifier)
      assert %{state: :deleted} = meta
    end
  end

  describe "Classifiers.structure_query/1" do
    setup :create_classifier

    test "creates a valid query", %{classifier: classifier, system_id: system_id} do
      metadata = %{"foo" => %{"bar" => "baz"}}

      %{id: id} =
        insert(:data_structure_version,
          metadata: metadata,
          data_structure: build(:data_structure, system_id: system_id)
        )

      assert [%{id: ^id}] =
               classifier
               |> Classifiers.structure_query()
               |> Repo.all()
    end
  end

  describe "Classifiers.classify/1" do
    setup :create_classifier

    test "classifies structures", %{classifier: classifier, system_id: system_id} do
      metadata = %{"foo" => %{"bar" => "baz"}}

      %{id: id1} =
        insert(:data_structure_version,
          metadata: metadata,
          data_structure: build(:data_structure, system_id: system_id),
          type: "foo_type"
        )

      %{id: id2} =
        insert(:data_structure_version,
          metadata: metadata,
          data_structure: build(:data_structure, system_id: system_id),
          type: "bar_type"
        )

      assert {:ok, %{} = multi} = Classifiers.classify(classifier, returning: true)

      assert %{"foo" => {1, [%{data_structure_version_id: ^id1}]}} = multi
      assert %{"bar" => {1, [%{data_structure_version_id: ^id2}]}} = multi
    end
  end

  describe "Classifiers.classify_many/2" do
    setup :create_structures

    test "applies multiple classifications",
         %{system_id: system_id, updated_at: updated_at} = context do
      classifier_names =
        1..5
        |> Enum.map(fn _ -> create_classifier(context) end)
        |> Enum.map(&Keyword.get(&1, :classifier))
        |> Enum.map(& &1.name)

      assert {:ok, %{} = res} = Classifiers.classify_many([system_id, 69], updated_at: updated_at)

      assert Enum.count(res) == 5

      Enum.each(res, fn {key, value} ->
        assert key in classifier_names
        assert %{"foo" => {5, nil}, "bar" => {5, nil}} = value
      end)

      assert {:ok, %{} = res} = Classifiers.classify_many([system_id, 69], updated_at: DateTime.utc_now())

      Enum.each(res, fn {key, value} ->
        assert key in classifier_names
        assert %{"foo" => {0, nil}, "bar" => {0, nil}} = value
      end)
    end
  end

  defp create_structures(%{system_id: system_id}) do
    require Integer

    ts = DateTime.utc_now()

    dsvs =
      Enum.map(1..10, fn x ->
        type = if Integer.is_even(x), do: "foo_type", else: "bar_type"

        insert(:data_structure_version,
          type: type,
          metadata: %{"foo" => %{"bar" => "baz"}},
          data_structure: build(:data_structure, system_id: system_id),
          updated_at: ts
        )
      end)

    [data_structure_versions: dsvs, updated_at: ts]
  end

  defp create_classifier(%{system_id: system_id}) do
    %{classifier_id: classifier_id} =
      insert(:regex_filter,
        path: ["metadata", "foo", "bar"],
        regex: "^baz$",
        classifier: build(:classifier, system_id: system_id)
      )

    insert(:regex_rule,
      path: ["type"],
      regex: "^foo_type$",
      classifier_id: classifier_id,
      class: "foo",
      priority: 0
    )

    insert(:values_rule,
      path: ["type"],
      values: ["bar_type"],
      classifier_id: classifier_id,
      class: "bar",
      priority: 10
    )

    [classifier: Repo.get!(Classifier, classifier_id)]
  end
end
