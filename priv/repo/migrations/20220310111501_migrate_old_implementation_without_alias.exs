defmodule TdDd.Repo.Migrations.MigrateOldImplementationWithoutAlias do
  use Ecto.Migration

  def change do
    execute(
      """
        update rule_implementations set dataset[1] =
        jsonb_set(dataset[1], '{"alias"}', '{"text": null, "index": 1}', true)
        where array_length(dataset, 1) = 1;
      """,
      """
        update rule_implementations set dataset[1] =
        dataset[1] - 'alias'
        where array_length(dataset, 1) = 1;
      """
    )
  end
end
