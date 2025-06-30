defmodule :"Elixir.TdDd.Repo.Migrations.Update implementation versions domain with the latest versions domain" do
  use Ecto.Migration

  alias Ecto.Query
  alias TdDd.Repo

  def up do
    execute("""
        with t as(
          select ri.implementation_ref, ri.domain_id
          from rule_implementations ri
            inner join (select implementation_ref, max(version) as version
                        from rule_implementations
                        group by implementation_ref) x on (ri.implementation_ref = x.implementation_ref and ri.version = x.version)
        )
        update rule_implementations
        set domain_id = t.domain_id
        from t
        where rule_implementations.implementation_ref = t.implementation_ref
    """)
  end

  def down do
  end
end
