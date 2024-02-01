defmodule TdDd.Repo.Migrations.DropImplementationRefToRuleImplementations do
  use Ecto.Migration


  def change do
    alter table("rule_implementations") do
      remove :implementation_ref
    end   
  end
end
