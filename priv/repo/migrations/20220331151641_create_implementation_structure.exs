defmodule TdDd.Repo.Migrations.CreateImplementationStructure do
  use Ecto.Migration

  import Ecto.Query

  @valid_types "'dataset', 'population', 'validation'"

  def up do
    execute("CREATE TYPE implementation_structure_type AS ENUM (#{@valid_types})")

    create table(:implementations_structures) do
      add :type, :implementation_structure_type, null: false
      add :deleted_at, :utc_datetime_usec
      add :implementation_id, references("rule_implementations", on_delete: :nothing), null: false
      add :data_structure_id, references("data_structures", on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(
             :implementations_structures,
             [:implementation_id, :data_structure_id, :type],
             name: :implementations_structures_implementation_structure_type
           )

    implementations_structures_data =
      "rule_implementations"
      |> select([i], %{
        id: i.id,
        implementation_type: i.implementation_type,
        raw_content: i.raw_content,
        dataset: i.dataset
      })
      |> repo().all()
      |> Enum.flat_map(fn %{id: implementation_id} = impl ->
        impl
        |> valid_implementation_structures()
        |> Enum.sort()
        |> Enum.dedup()
        |> Enum.map(fn data_structure_id ->
          now = DateTime.utc_now()

          %{
            implementation_id: implementation_id,
            data_structure_id: data_structure_id,
            type: "dataset",
            inserted_at: now,
            updated_at: now
          }
        end)
      end)

    flush()

    "implementations_structures"
    |> repo().insert_all(implementations_structures_data)
  end

  def valid_implementation_structures(%{dataset: [_ | _] = dataset}) do
    dataset
    |> Enum.map(fn dataset_row -> dataset_row |> Map.get("structure") |> Map.get("id") end)
    |> Enum.filter(fn ds_id ->
      not is_nil(ds_id) and
        "data_structures"
        |> where(id: ^ds_id)
        |> repo().exists?()
    end)
  end

  def valid_implementation_structures(%{
        raw_content: %{
          "database" => database,
          "dataset" => dataset,
          "source_id" => source_id
        }
      }) do
    dataset
    |> String.split([" ", "\n", "\t"])
    |> Enum.flat_map(fn name ->
      "data_structure_versions"
      |> select([dsv], %{data_structure_id: dsv.data_structure_id})
      |> where([dsv], is_nil(dsv.deleted_at))
      |> where([dsv], dsv.name == ^name)
      |> where([dsv], fragment("?->>? = ?", dsv.metadata, "database", ^database))
      |> join(:inner, [dsv], ds in "data_structures", on: dsv.data_structure_id == ds.id)
      |> where([_dsv, ds], ds.source_id == ^source_id)
      |> repo().all()
      |> Enum.map(fn %{data_structure_id: ds_id} -> ds_id end)
    end)
  end

  def valid_implementation_structures(_), do: []

  def down do
    drop unique_index(
           :implementations_structures,
           [:implementation_id, :data_structure_id, :type],
           name: :implementations_structures_implementation_structure_type
         )

    drop table(:implementations_structures)

    execute("DROP TYPE implementation_structure_type")
  end
end
