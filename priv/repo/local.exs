# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TdBg.Repo.insert!(%TdBg.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias TdDd.DataStructures.DataStructure
alias TdDd.DataStructures.DataField
alias TdDd.Repo
alias Ecto.Changeset

create_data_structure = fn(ou, system, group, name) ->
  Repo.insert!(%DataStructure{
    description: "#{ou} #{system} #{group} #{name}",
    group: group,
    last_change_at: DateTime.utc_now(),
    last_change_by: 1234,
    name: name,
    system: system,
    type: "one",
    ou:   ou,
    lopd: "EM"
  })
end

domains = ["Dominio1", "Dominio2", "Dominio3"]
systems = ["s1", "s2", "s3"]
groups = ["g1", "g2", "g3"]
names  = ["n1", "n2", "n3"]

Enum.each(domains, fn(domain) ->
  Enum.each(systems, fn(system) ->
    Enum.each(groups, fn(group) ->
      Enum.each(names, fn(name) ->
        create_data_structure.(domain, "#{domain} #{system}",
                                       "#{domain} #{system} #{group}",
                                       "#{domain} #{system} #{group} #{name}")
      end)
    end)
  end)
end)

#
#
#
# Repo.insert!(%DataField{
#   business_concept_id: "concept",
#   description: "data field descripton",
#   last_change_at: DateTime.utc_now(),
#   last_change_by: 1234,
#   name: "data field name",
#   nullable: true,
#   precision: "varchar",
#   type: "data field name",
#   data_structure_id: data_structure_1.id
# })
