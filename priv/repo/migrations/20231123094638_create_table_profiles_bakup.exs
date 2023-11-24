defmodule TdDd.Repo.Migrations.CreateTableProfilesBakup do
  use Ecto.Migration

  def change do

    execute(
      """
      SELECT * INTO public.profiles_bakup_rollback  FROM public.profiles
      """,
      "DROP Table IF EXISTS profiles_bakup_rollback"
    )

   
  end
end
