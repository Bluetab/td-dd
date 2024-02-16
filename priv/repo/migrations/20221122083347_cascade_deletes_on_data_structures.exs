defmodule TdDd.Repo.Migrations.CascadeDeletesOnDataStructures do
  use Ecto.Migration

  def change do
    alter table("grant_requests") do
      modify :data_structure_id, references("data_structures", on_delete: :delete_all),
        null: false,
        from: references("data_structures")
    end

    alter table("data_structures_links") do
      modify :source_id, references("data_structures", on_delete: :delete_all),
        from: references("data_structures")

      modify :target_id, references("data_structures", on_delete: :delete_all),
        from: references("data_structures")
    end

    alter table("accesses") do
      modify :data_structure_external_id,
             references("data_structures",
               column: :external_id,
               type: :string,
               on_delete: :delete_all
             ),
             from: references("data_structures", column: :external_id, type: :string)
    end

    alter table("profile_events") do
      modify :profile_execution_id, references("profile_executions", on_delete: :delete_all),
        null: false,
        from: references("profile_executions")
    end

    alter table("grant_request_groups") do
      modify :modification_grant_id, references("grants", on_delete: :delete_all),
        from: references("grants")
    end
  end
end
