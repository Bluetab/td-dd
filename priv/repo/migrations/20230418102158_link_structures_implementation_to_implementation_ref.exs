defmodule TdDd.Repo.Migrations.LinkStructuresImplementationToImplementationRef do
  use Ecto.Migration

  def change do
    execute(
      """
      delete from implementations_structures
        where id in (
          select is2.id as is_id
          from implementations_structures is2
            inner join rule_implementations ri on (ri.id = is2.implementation_id)
            left join (
              select ri.id
              from implementations_structures is2
                inner join rule_implementations ri on (ri.id = is2.implementation_id)
              where
                ri.id <> ri.implementation_ref and ri.status = 'published'
            ) implementations_to_keep on (ri.id = implementations_to_keep.id)
            left join (
              select ri.implementation_ref
              from rule_implementations ri
              group by
                ri.implementation_ref
              having
                count(ri.implementation_ref) = 1
            ) implementations_without_versions
              on (ri.implementation_ref = implementations_without_versions.implementation_ref)
          where
            implementations_to_keep.id is null
            and implementations_without_versions.implementation_ref is null)
      """,
      ""
    )

    execute(
      """
      update implementations_structures
      set implementation_id = ri.implementation_ref
      from rule_implementations ri
      where ri.id = implementations_structures.implementation_id
      """,
      ""
    )
  end
end
