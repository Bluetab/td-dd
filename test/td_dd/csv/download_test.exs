defmodule TdDd.DownloadTest do
  @moduledoc """
  Tests download of structures in csv format
  """
  use TdDd.DataCase

  alias TdCache.TemplateCache

  def create_template(template) do
    template
    |> Map.put(:updated_at, DateTime.utc_now())
    |> TemplateCache.put()

    template
  end

  describe "Structures download" do
    alias TdDd.CSV.Download

    test "download empty csv" do
      csv = Download.to_csv([])
      assert csv == ""
    end

    test "to_csv/1 return cvs content to download" do
      template_name = "Table"
      field_name = "add_info1"
      field_label = "Add Info 1"

      create_template(%{
        id: 0,
        name: template_name,
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => field_name,
            "type" => "list",
            "label" => field_label
          }
        ]
      })

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        df_content: %{
          field_name => ["field_value"]
        },
        inserted_at: "2018-05-05",
        deleted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        ou: "BK",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: "Table",
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]
      csv = Download.to_csv(structures)

      assert csv ==
               """
               type;name;group;ou;system;path;description;external_id;inserted_at;deleted_at;Add Info 1\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{structure_1.ou};#{
                 Map.get(structure_1.system, "name")
               };CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{
                 structure_1.description
               };#{structure_1.external_id};#{structure_1.inserted_at};#{structure_1.deleted_at};field_value\r
               """
    end
  end
end
