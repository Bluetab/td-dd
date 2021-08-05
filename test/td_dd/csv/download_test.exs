defmodule TdDd.DownloadTest do
  @moduledoc """
  Tests download of structures in csv format
  """
  use TdDd.DataCase

  alias TdCache.TemplateCache
  alias TdDd.CSV.Download

  def create_template(template) do
    template
    |> Map.put(:updated_at, DateTime.utc_now())
    |> TemplateCache.put()

    template
  end

  describe "Structures download" do
    test "download empty csv" do
      csv = Download.to_csv([])
      assert csv == ""
    end

    test "to_csv/1 return cvs content to download" do
      template_name = "Table"
      field_name = "add_info1"
      field_label = "Add Info 1"
      template_id = 1
      type = "Columna"

      create_template(%{
        id: template_id,
        name: template_name,
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => field_name,
                "type" => "list",
                "label" => field_label
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: type, template_id: template_id)
      domain_name = "domain_1"

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        latest_note: %{
          field_name => ["field_value"]
        },
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]
      csv = Download.to_csv(structures)

      assert csv ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;Add Info 1\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};field_value\r
               """
    end
  end

  describe "Lineage download" do
    test "linage_to_csv/3 return csv content" do
      contains_row = [
        source: %{external_id: "eid1", name: "name", class: "Group"},
        target: %{external_id: "eid2", name: "name1", class: "Group"}
      ]

      contains = [contains_row]

      depends_row = [
        source: %{external_id: "eid3", name: "name2", class: "Resource"},
        target: %{external_id: "eid4", name: "name3", class: "Resource"}
      ]

      depends = [depends_row]

      headers = %{
        "source_external_id" => "Id Origen",
        "source_name" => "Nombre Origen",
        "source_class" => "Tipo Origen",
        "target_external_id" => "Id Destino",
        "target_name" => "Nombre Destino",
        "target_class" => "Tipo Destino",
        "relation_type" => "Tipo Relación"
      }

      assert Download.linage_to_csv(contains, depends, headers) ==
               """
               Id Origen;Nombre Origen;Tipo Origen;Id Destino;Nombre Destino;Tipo Destino;Tipo Relación\r
               #{contains_row[:source].external_id};#{contains_row[:source].name};Group;#{contains_row[:target].external_id};#{contains_row[:target].name};Group;CONTAINS\r
               #{depends_row[:source].external_id};#{depends_row[:source].name};Resource;#{depends_row[:target].external_id};#{depends_row[:target].name};Resource;DEPENDS\r
               """
    end
  end
end
