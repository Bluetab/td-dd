defmodule TdDd.Repo.Migrations.AddQualityEventsIndex do
  use Ecto.Migration

  def change do
    create index("quality_events", [:execution_id])
    create index("executions", [:implementation_id])
  end
end
