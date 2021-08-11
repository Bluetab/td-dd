defmodule TdDd.Repo.Migrations.CreateGrantConstraints do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS btree_gist", "")

    # Delete overlapping grants
    execute(
      """
      delete from grants where id in (
        select g1.id
        from grants g1
        join grants g2 on g1.user_id = g2.user_id and g2.id > g1.id
        and daterange(g1.start_date, g1.end_date, '[]') && daterange(g2.start_date, g2.end_date, '[]')
      )
      """,
      ""
    )

    create constraint("grants", :date_range, check: "end_date is null or end_date >= start_date")

    create constraint("grants", :no_overlap,
             exclude:
               ~s|gist (data_structure_id WITH =, user_id WITH =, daterange(start_date, end_date, '[]') WITH &&)|
           )
  end
end
