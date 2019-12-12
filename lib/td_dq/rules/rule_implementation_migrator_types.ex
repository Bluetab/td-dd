defmodule TdDq.Rules.RuleImplementation.MigratorTypes do
  @moduledoc """
  GenServer to put structures used in rule implementations in cache
  """

  import Ecto.Query

  alias TdDq.Repo
  alias TdDq.Rules

  require Logger

  defp get_condition_row(name, structure_id) do
    %{
      operator: %{
        name: name
      },
      structure: %{id: structure_id}
    }
  end

  defp get_condition_row(name, value_type, value, structure_id) do
    %{
      operator: %{
        name: name,
        value_type: value_type
      },
      structure: %{id: structure_id},
      value: value
    }
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: %{"column" => _column, "group" => _group, "table" => _table},
        rule_type_name: _any,
        rule_type_params: _rule_type_params,
        rule_rule_type_params: _rule_rule_type_params
      }) do
    Logger.info("Skipped migration of rule_implementation with id #{id}")
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      })
      when rule_type_name in [
             "002_mandatory_field",
             "mandatory_field",
             "FIELD_NOT_NULL"
           ] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]
    validations = [get_condition_row("not_empty", field_id)]
    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["003_integer_values_range", "integer_values_range"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    max_value = Map.get(rule_rule_type_params, "max_value")
    min_value = Map.get(rule_rule_type_params, "min_value")
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "between",
        "number",
        [%{raw: min_value}, %{raw: max_value}],
        parent_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["004_max_value", "max_value"] do

    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"max_value" => max_value} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "lte",
        "number",
        [%{raw: max_value}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["005_min_value", "min_value"] do

    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"min_value" => min_value} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "gte",
        "number",
        [%{raw: min_value}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: %{"num_decimals" => num_decimals}
      })
      when rule_type_name in ["006_decimal_format", "decimal_format"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "number_of_decimals",
        "number",
        [%{raw: num_decimals}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      })
      when rule_type_name in ["007_numeric_format", "numeric_format"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "number"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "008_date_format",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "date"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["009_dates_range", "dates_range"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    max_value = Map.get(rule_rule_type_params, "max_date")
    min_value = Map.get(rule_rule_type_params, "min_date")
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "between",
        "date",
        [%{raw: min_value}, %{raw: max_value}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "rango_fechas",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: %{
          "max_date" => "Último período de validación",
          "min_date" => min_value
        }
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)

    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "gte",
        "date",
        [%{raw: min_value}],
        field_id
      ),
      get_condition_row(
        "lte",
        "string",
        [%{raw: "last_validation_period"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["010_max_date", "max_date"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"max_date" => max_value} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "lte",
        "date",
        [%{raw: max_value}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["011_min_date", "min_date"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"min_date" => min_value} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "lte",
        "date",
        [%{raw: min_value}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["012_max_text", "max_text"] do

    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"num_characters" => num} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "length_lte",
        "number",
        [%{raw: num}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["013_min_text", "min_text"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"num_characters" => num} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "length_lte",
        "number",
        [%{raw: num}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      })
      when rule_type_name in ["014_in_list", "in_list", "lista_valores"] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    %{"values_list" => values} = rule_rule_type_params
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "in_list",
        "string_list",
        [%{raw: values}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "comparacion_magnitudes"
      }) do
    field_id = system_params["campo"]["id"]
    name = system_params["dato_relacionado"]["name"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "eq",
        "string",
        [%{raw: name}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "datos_ausentes",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "not_empty",
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: rule_type_name,
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      })
      when rule_type_name in [
             "duplicidad",
             "001_unique_values",
             "unique_values",
             "FIELD_NOT_DUPLICATED"
           ] do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]
    validations = [get_condition_row("unique", field_id)]
    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "consistency"
      }) do
    field_id = system_params["campo1"]["id"]
    campo2_id = system_params["campo2"]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "references",
        "field",
        [%{raw: campo2_id}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "date_format",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "date"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "VALID_DNI_AND_CIF",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "dni_or_cif"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "email",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]}
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "email"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "integridad_datos_maestros"
      }) do
    field_id = system_params |> Map.get("campo") |> Map.get("id")
    master_data_id = system_params |> Map.get("dato_maestro") |> Map.get("id")
    master_data_name = system_params |> Map.get("dato_maestro") |> Map.get("name")
    parent_id = get_parent_id(field_id)

    dataset = [%{structure: %{id: parent_id}}]

    validation =
      cond do
        not is_nil(master_data_id) ->
          get_condition_row(
            "references",
            "field",
            [%{id: master_data_id}],
            field_id
          )

        not is_nil(master_data_name) ->
          get_condition_row(
            "references",
            "string",
            [%{raw: master_data_name}],
            field_id
          )

        true ->
          %{}
      end

    update_rule_implementation(id, dataset, [], [validation])
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "rango_numericos",
        rule_type_params: %{"system_params" => [%{"name" => param_name}]},
        rule_rule_type_params: rule_rule_type_params
      }) do
    field_id = system_params[param_name]["id"]
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    max = Map.get(rule_rule_type_params, "max_number")
    min = Map.get(rule_rule_type_params, "min_number")

    validations = [
      get_condition_row(
        "between",
        "number",
        [%{raw: min}, %{raw: max}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "phone"
      }) do
    phone_id = system_params |> Map.get("campo_telefono") |> Map.get("id")
    country_id = system_params |> Map.get("pais") |> Map.get("id")
    parent_id = get_parent_id(phone_id)

    dataset = [%{structure: %{id: parent_id}}]
    phone_validation = get_condition_row("format_of", "string", [%{raw: "phone"}], phone_id)
    country_population = get_condition_row("eq", "string", [%{raw: "ES"}], country_id)

    update_rule_implementation(id, dataset, [country_population], [phone_validation])
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: system_params,
        rule_type_name: "integridad_datos_relacionados"
      }) do
    field_id = system_params |> Map.get("campo") |> Map.get("id")
    related_data_id = system_params |> Map.get("dato_relacionado") |> Map.get("id")
    related_data_name = system_params |> Map.get("dato_relacionado") |> Map.get("name")
    parent_id = get_parent_id(field_id)

    dataset = [%{structure: %{id: parent_id}}]

    validation =
      cond do
        not is_nil(related_data_id) ->
          get_condition_row(
            "references",
            "field",
            [%{id: related_data_id}],
            field_id
          )

        not is_nil(related_data_name) ->
          get_condition_row(
            "references",
            "string",
            [%{raw: related_data_name}],
            field_id
          )

        true ->
          %{}
      end

    update_rule_implementation(id, dataset, [], [validation])
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: %{
          "Campo" => %{
            "id" => campo_id
          },
          "Campo A Comparar" => %{
            "id" => campo_a_comparar_id
          },
          "Symbol" => ">="
        },
        rule_type_name: "IS_NUMERIC_AND_COMPARE"
      }) do
    parent_id = get_parent_id(campo_id)

    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "gte",
        "field",
        [%{id: campo_a_comparar_id}],
        campo_id
      ),
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "number"}],
        campo_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: %{
          "Campo" => %{
            "id" => campo_id
          }
        },
        rule_type_name: "IS_NUMERIC"
      }) do
    parent_id = get_parent_id(campo_id)

    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "number"}],
        campo_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: %{"Campo" => %{"id" => field_id}},
        rule_type_name: "VALID_DATE_AND_LASTDAYMONTH"
      }) do
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "format_of",
        "string",
        [%{raw: "date"}],
        field_id
      )
    ]

    population = [
      get_condition_row(
        "eq",
        "string",
        [%{raw: "last_day_of_month"}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, population, validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        system_params: %{"Campo" => %{"id" => field_id}, "REGEXP" => regex},
        rule_type_name: "MEETS_REGEXP"
      }) do
    parent_id = get_parent_id(field_id)
    dataset = [%{structure: %{id: parent_id}}]

    validations = [
      get_condition_row(
        "regex_format",
        "string",
        [%{raw: regex}],
        field_id
      )
    ]

    update_rule_implementation(id, dataset, [], validations)
  end

  def migrate_rule_implementation(%{
        id: id,
        rule_type_name: rule_type_name
      }) do
    Logger.info(
      "-- Rule implementation with id #{id} and rule type #{rule_type_name} has not been migrated"
    )
  end

  defp update_rule_implementation(id, dataset, population, validations) do
    query = from(ri in "rule_implementations")

    query
    |> update([ri], set: [dataset: ^dataset, population: ^population, validations: ^validations])
    |> where([ri], ri.id == ^id)
    |> Repo.update_all([])

    rule_implementation = Rules.get_rule_implementation!(id)
    Rules.add_rule_implementation_structure_links(rule_implementation)
  end

  defp get_parent_id(field_id) do
    {:ok, structure} = TdCache.StructureCache.get(field_id)

    case Map.get(structure || %{}, :parent_id) do
      nil ->
        nil

      parent_id ->
        String.to_integer(parent_id)
    end
  end
end
