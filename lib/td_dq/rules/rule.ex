defmodule TdDq.Rules.Rule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleType

  @statuses ["defined"]
  @tag_valid_keys ["name"]

  schema "rules" do
    field(:business_concept_id, :string)
    field(:description, :string)
    field(:goal, :integer)
    field(:minimum, :integer)
    field(:name, :string)
    field(:population, :string)
    field(:priority, :string)
    field(:weight, :integer)
    field(:status, :string, default: "defined")
    field(:version, :integer, default: 1)
    field(:updated_by, :integer)
    field(:principle, :map)
    field(:type_params, :map)
    field(:tag, :map)
    belongs_to(:rule_type, RuleType)

    timestamps()
  end

  @doc false
  def changeset(%Rule{} = rule, attrs) do
    rule
    |> cast(attrs, [
      :business_concept_id,
      :name,
      :description,
      :weight,
      :priority,
      :population,
      :goal,
      :minimum,
      :status,
      :version,
      :updated_by,
      :principle,
      :rule_type_id,
      :type_params,
      :tag
    ])
    |> validate_required([
      :business_concept_id,
      :name,
      :goal,
      :minimum,
      :principle,
      :rule_type_id,
      :type_params
    ])
    |> validate_tags()
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_goal
    |> foreign_key_constraint(:rule_type_id)
  end

  defp validate_goal(changeset) do
    case changeset.valid? do
      true ->
        minimum = get_field(changeset, :minimum)
        goal = get_field(changeset, :goal)

        case minimum <= goal do
          true -> changeset
          false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
        end

      _ ->
        changeset
    end
  end

  defp validate_tags(changeset) do
    case changeset.valid? do
      true -> validate_map_tag_format(get_change(changeset, :tag), changeset)
      _ -> changeset
    end
  end

  defp validate_map_tag_format(nil, changeset), do: changeset

  defp validate_map_tag_format(tag_map, changeset) when tag_map == %{}, do: changeset

  defp validate_map_tag_format(%{"tags" => list_tags}, changeset) when is_list(list_tags) do
    with true <-
           Enum.all?(list_tags, fn tag ->
             is_map(tag) &&
               Map.keys(tag)
               |> Enum.all?(fn key ->
                 Enum.member?(@tag_valid_keys, key) && is_binary(Map.fetch!(tag, key))
               end)
           end) do
            changeset
           else
            false -> changeset |> add_error(:tag, "invalid.tag.map.format")
           end
  end

  defp validate_map_tag_format(_, changeset) do
    changeset |> add_error(:tag, "invalid.not.list.tag.format")
  end

  def get_statuses do
    @statuses
  end

  def defined_status do
    "defined"
  end
end
