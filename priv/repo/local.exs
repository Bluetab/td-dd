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

data_structure_1 = Repo.insert!(%DataStructure{
  description: "description 1",
  group: "group 1",
  last_change_at: DateTime.utc_now(),
  last_change_by: 1234,
  name: "name 1",
  system: "system 1",
  type: "type 1",
  ou:   "Nombre del dominio",
  lopd: "lopd 1"
})

Repo.insert!(%DataField{
  business_concept_id: "concept",
  description: "data field descripton",
  last_change_at: DateTime.utc_now(),
  last_change_by: 1234,
  name: "data field name",
  nullable: true,
  precision: "varchar",
  type: "data field name",
  data_structure_id: data_structure_1.id
})

Repo.insert!(%DataStructure{
  description: "description 2",
  group: "group 2",
  last_change_at: DateTime.utc_now(),
  last_change_by: 1234,
  name: "name 2",
  system: "system 2",
  type: "type 2",
  ou:   "Nombre del dominio",
  lopd: "lopd 2"
})
