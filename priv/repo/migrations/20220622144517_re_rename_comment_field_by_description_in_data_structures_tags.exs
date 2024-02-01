# defmodule TdDd.Repo.Migrations.RenameDescriptionFieldByCommentInDataStructuresTags do
defmodule TdDd.Repo.Migrations.ReRenameCommentByDescriptionFieldInDataStructuresTags do
  use Ecto.Migration

  def up do
    # Rename comment column by description
    rename table("data_structures_tags"), :comment, to: :description
    # Add not nullable flag to description
    alter table("data_structures_tags") do
      modify :description, :string, size: 1_000, null: false
  end

  def down do    
    # Remove not nullable of description column
    alter table("data_structures_tags") do
      modify :description, :string, size: 1_000, null: true
    end

    # Rename description column by comment
    rename table("data_structures_tags"), :description, to: :comment  
    end
  end
end
