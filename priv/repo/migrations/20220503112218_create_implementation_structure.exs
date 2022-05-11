defmodule TdDd.Repo.Migrations.CreateImplementationStructure do
  use Ecto.Migration

  @valid_types "'dataset', 'population', 'validation'"

  def up do
    drop_if_exists table("implementations_structures")
    execute("DROP TYPE IF EXISTS implementation_structure_type")

    execute("CREATE TYPE implementation_structure_type AS ENUM (#{@valid_types})")

    create table("implementations_structures") do
      add :type, :implementation_structure_type, null: false
      add :deleted_at, :utc_datetime_usec

      add :implementation_id, references("rule_implementations", on_delete: :delete_all),
        null: false

      add :data_structure_id, references("data_structures", on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(
             "implementations_structures",
             [:implementation_id, :data_structure_id, :type],
             name: :implementations_structures_implementation_structure_type
           )

    # INSERT IMPLEMENTATION DATASET
    execute("""
      INSERT INTO implementations_structures(implementation_id, data_structure_id, type, inserted_at, updated_at)
        SELECT implementation_id, data_structure_id, 'dataset', updated_at, updated_at from (
          SELECT DISTINCT
            id as implementation_id,
            (unnest(dataset)#>'{structure,id}')::integer as data_structure_id,
            updated_at
          FROM rule_implementations
        ) AS implementation_data_structures
        WHERE data_structure_id in (
          SELECT id FROM data_structures
        )
    """)

    # INSERT IMPLEMENTATION VALIDATIONS
    execute("""
      INSERT INTO implementations_structures(implementation_id, data_structure_id, type, inserted_at, updated_at)
        SELECT implementation_id, data_structure_id, 'validation', updated_at, updated_at from (
          SELECT DISTINCT
            id as implementation_id,
            (unnest(validations)#>'{structure,id}')::integer as data_structure_id,
            updated_at
          FROM rule_implementations
        ) AS implementation_data_structures
        WHERE data_structure_id in (
          SELECT id FROM data_structures
        )
    """)

    # INSERT RAW IMPLEMENTATION DATASET
    execute("""
      INSERT INTO implementations_structures(implementation_id, data_structure_id, type, inserted_at, updated_at)
        SELECT implementation_id, data_structure_id, 'dataset', words.updated_at, words.updated_at
        FROM
          (
            SELECT DISTINCT
              id AS implementation_id,
              lower(regexp_split_to_table(raw_content#>>'{dataset}', '[\s\.]+')) AS word,
              lower(raw_content ->> 'database') AS db,
              (raw_content ->> 'source_id')::INTEGER AS source_id,
              updated_at
            FROM rule_implementations
          ) AS words
          JOIN data_structure_versions dsv
            ON words.db = lower(dsv.metadata ->> 'database')
            AND replace(words.word, '"', '') = lower(dsv.name)
            AND dsv.deleted_at IS NULL
            AND dsv.class = 'table'
          JOIN data_structures ds
            ON dsv.data_structure_id = ds.id
            AND ds.source_id = words.source_id
          WHERE word NOT IN (
            SELECT word FROM pg_get_keywords()
          )
    """)

    # INSERT RAW IMPLEMENTATION VALIDATIONS
    execute("""
      INSERT INTO implementations_structures(implementation_id, data_structure_id, type, inserted_at, updated_at)
        SELECT implementation_id, data_structure_id, 'validation', words.updated_at, words.updated_at
        FROM
          (
            SELECT DISTINCT
              id AS implementation_id,
              lower(regexp_split_to_table(raw_content#>>'{validations}', '[\s\.]+')) AS word,
              replace(lower(regexp_split_to_array(raw_content#>>'{dataset}', '[\s\.]+')::text), '\\"', '')::text[] AS dataset_words,
              lower(raw_content ->> 'database') AS db,
              (raw_content ->> 'source_id')::INTEGER AS source_id,
              updated_at
            FROM rule_implementations
          ) AS words
          JOIN data_structure_versions dsv
            ON words.db = lower(dsv.metadata ->> 'database')
            AND lower(dsv.metadata ->> 'table') = any(words.dataset_words)
            AND words.word = lower(dsv.name)
            AND dsv.deleted_at IS NULL
            AND dsv.class = 'field'
          JOIN data_structures ds
            ON dsv.data_structure_id = ds.id
            AND ds.source_id = words.source_id
          WHERE word NOT IN (
            SELECT word FROM pg_get_keywords()
          )
    """)
  end

  def down do
    drop table("implementations_structures")
    execute("DROP TYPE IF EXISTS implementation_structure_type")
  end
end
