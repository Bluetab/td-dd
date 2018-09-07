# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TdDq.Repo.insert!(%TdDq.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TdDq.Rules
alias TdDq.Rules.RuleType

alias TdDq.Repo

qrts = [
  %RuleType{name: "mandatory_field", params: %{"system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "min_text", params: %{"type_params": [%{"name": "num_characters", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "max_text", params: %{"type_params": [%{"name": "num_characters", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "date_format", params: %{"system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "numeric_format", params: %{"system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "decimal_format", params: %{"type_params": [%{"name": "num_decimals", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "in_list", params: %{"type_params": [%{"name": "values_list", "type": "list"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "unique_values", params: %{"system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "min_value", params: %{"type_params": [%{"name": "min_value", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "max_value", params: %{"type_params": [%{"name": "max_value", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "integer_values_range", params: %{"type_params": [%{"name": "min_value", "type": "integer"}, %{"name": "max_value", "type": "integer"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "integrity", params: %{"system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "max_date", params: %{"type_params": [%{"name": "max_date", "type": "date"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "min_date", params: %{"type_params": [%{"name": "min_date", "type": "date"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "dates_range", params: %{"type_params": [%{"name": "min_date", "type": "date"}, %{"name": "max_date", "type": "date"}], "system_params": [%{"name": "table", "type": "string"}, %{"name": "column", "type": "string"}]}},
  %RuleType{name: "custom_validation", params: %{}}
]

for qrt <- qrts do
  case Rules.get_rule_type_by_name(qrt.name) do
    nil -> qrt |> Repo.insert!
    qrt -> qrt
  end
end
