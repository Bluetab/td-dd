defmodule TdDd.Repo.Migrations.MatchFkIdColumns do
  use Ecto.Migration

  def up do
    alter table(:data_structure_relations) do
      modify(:relation_type_id, :bigint)
    end

    alter table(:data_structure_types) do
      modify(:template_id, :bigint)
    end

    alter table(:data_structures) do
      modify(:system_id, :bigint)
    end

    alter table(:execution_groups) do
      modify(:created_by_id, :bigint)
    end

    alter table(:grant_request_approvals) do
      modify(:user_id, :bigint)
    end

    alter table(:grant_request_groups) do
      modify(:user_id, :bigint)
      modify(:created_by_id, :bigint)
    end

    alter table(:grant_request_status) do
      modify(:user_id, :bigint)
    end

    alter table(:profile_execution_groups) do
      modify(:created_by_id, :bigint)
    end

    alter table(:rules) do
      modify(:business_concept_id, :bigint)
    end

    alter table(:units) do
      modify(:domain_id, :bigint)
    end

    alter table(:user_search_filters) do
      modify(:user_id, :bigint)
    end
  end

  def down do
    alter table(:data_structure_relations) do
      modify(:relation_type_id, :integer)
    end

    alter table(:data_structure_types) do
      modify(:template_id, :integer)
    end

    alter table(:data_structures) do
      modify(:system_id, :integer)
    end

    alter table(:execution_groups) do
      modify(:created_by_id, :integer)
    end

    alter table(:grant_request_approvals) do
      modify(:user_id, :integer)
    end

    alter table(:grant_request_groups) do
      modify(:user_id, :integer)
      modify(:created_by_id, :integer)
    end

    alter table(:grant_request_status) do
      modify(:user_id, :integer)
    end

    alter table(:profile_execution_groups) do
      modify(:created_by_id, :integer)
    end

    alter table(:rules) do
      modify(:business_concept_id, :integer)
    end

    alter table(:units) do
      modify(:domain_id, :integer)
    end

    alter table(:user_search_filters) do
      modify(:user_id, :integer)
    end
  end
end
