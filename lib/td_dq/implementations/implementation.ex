defmodule TdDq.Implementations.Implementation do
  @moduledoc """
  Ecto Schema module for Quality Rule Implementations
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Assertions.Changeset
  alias Ecto.Changeset
  alias TdDd.Repo
  alias TdDfLib.Format
  alias TdDfLib.Validation
  alias TdDq.Implementations
  alias TdDq.Implementations.Conditions
  alias TdDq.Implementations.DatasetRow
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure
  alias TdDq.Implementations.RawContent
  alias TdDq.Implementations.SegmentsRow
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult
  alias TdDq.Search.Helpers

  @valid_result_types ~w(percentage errors_number deviation)
  @cast_fields [
    :domain_id,
    :deleted_at,
    :df_content,
    :df_name,
    :executable,
    :goal,
    :implementation_key,
    :implementation_type,
    :minimum,
    :result_type,
    :rule_id,
    :status,
    :version
  ]

  @typedoc "A quality rule implementation"
  @type t :: %__MODULE__{}

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:implementation_type, :string, default: "default")
    field(:executable, :boolean, default: true)
    field(:deleted_at, :utc_datetime_usec)
    field(:domain_id, :integer)
    field(:domain, :map, virtual: true)
    field(:df_name, :string)
    field(:df_content, :map)
    field(:template, :map, virtual: true)
    field(:goal, :float)
    field(:minimum, :float)
    field(:result_type, :string, default: "percentage")

    field(:status, Ecto.Enum,
      values: [:draft, :pending_approval, :rejected, :published, :versioned, :deprecated]
    )

    field(:version, :integer)

    belongs_to(:implementation_ref_struct, Implementation, foreign_key: :implementation_ref)

    has_many(:versions, Implementation,
      foreign_key: :implementation_ref,
      references: :implementation_ref
    )

    embeds_one(:raw_content, RawContent, on_replace: :delete)
    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:populations, Conditions, on_replace: :delete)
    embeds_many(:validation, Conditions, on_replace: :delete)
    embeds_many(:segments, SegmentsRow, on_replace: :delete)

    belongs_to(:rule, Rule)

    has_many(:results, RuleResult)

    has_many(:data_structures, ImplementationStructure,
      foreign_key: :implementation_id,
      references: :implementation_ref,
      where: [deleted_at: nil]
    )

    has_many(:dataset_structures, ImplementationStructure,
      foreign_key: :implementation_id,
      references: :implementation_ref,
      where: [deleted_at: nil, type: :dataset]
    )

    has_many(:dataset_sources, through: [:dataset_structures, :source])

    timestamps(type: :utc_datetime_usec)
  end

  def valid_result_types, do: @valid_result_types

  def changeset(%__MODULE__{} = implementation, %{"populations" => [population | _]} = params)
      when is_list(population) do
    populations =
      params
      |> Map.get("populations")
      |> Enum.map(&%{"conditions" => &1})

    changeset(implementation, %{params | "populations" => populations})
  end

  def changeset(
        %__MODULE__{} = implementation,
        %{"validation" => [validations | _]} = params
      )
      when is_list(validations) do
    validation =
      params
      |> Map.get("validation")
      |> Enum.map(&%{"conditions" => &1})

    changeset(implementation, %{params | "validation" => validation})
  end

  def changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, @cast_fields)
    |> put_change(:updated_at, DateTime.utc_now())
    |> changeset_validations(implementation, params)
  end

  def status_changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, [:status, :version, :deleted_at])
    |> put_change(:updated_at, DateTime.utc_now())
    |> validate_required([:status, :version])
    |> validate_or_put_implementation_key
  end

  def implementation_ref_changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, [:implementation_ref])
    |> validate_required(:implementation_ref)
  end

  def changeset_validations(%Ecto.Changeset{} = changeset, %__MODULE__{} = implementation, params) do
    changeset
    |> validate_required([
      :domain_id,
      :executable,
      :goal,
      :implementation_type,
      :minimum,
      :result_type,
      :status,
      :version
    ])
    |> validate_inclusion(:implementation_type, ["default", "raw", "basic"])
    |> validate_inclusion(:result_type, @valid_result_types)
    |> validate_or_put_implementation_key()
    |> maybe_put_identifier(implementation, params)
    |> maybe_put_status()
    |> validate_content()
    |> validate_goal()
    |> custom_changeset(implementation)
    |> foreign_key_constraint(:rule_id)
  end

  defp maybe_put_status(%Changeset{} = changeset) do
    case Changeset.fetch_field(changeset, :status) do
      {:data, :rejected} -> put_change(changeset, :status, :draft)
      _ -> changeset
    end
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{df_content: old_content} = _implementation,
         %{"df_name" => template_name} = _params
       ) do
    maybe_put_identifier_aux(changeset, old_content, template_name)
  end

  defp maybe_put_identifier(
         changeset,
         %__MODULE__{} = _implementation,
         %{"df_name" => template_name} = _params
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier(changeset, _implementation, _params) do
    changeset
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{df_content: changeset_content}} = changeset,
         old_content,
         template_name
       ) do
    new_content = Format.maybe_put_identifier(changeset_content, old_content, template_name)
    put_change(changeset, :df_content, new_content)
  end

  defp maybe_put_identifier_aux(changeset, _, _) do
    changeset
  end

  defp validate_or_put_implementation_key(%Changeset{valid?: true} = changeset) do
    case get_field(changeset, :implementation_key) do
      nil ->
        put_change(changeset, :implementation_key, Implementations.next_key())

      _ ->
        changeset
        |> validate_required(:implementation_key)
        |> validate_length(:implementation_key, max: 255)
        |> unique_constraint(:implementation_key,
          name: :published_implementation_key_index,
          message: "duplicated"
        )
        |> unique_constraint(:implementation_key,
          name: :draft_implementation_key_index,
          message: "duplicated"
        )
        |> validate_implementation_key_is_not_used()
    end
  end

  defp validate_or_put_implementation_key(%Changeset{} = changeset), do: changeset

  defp validate_implementation_key_is_not_used(
         %{changes: %{implementation_key: implementation_key}} = changeset
       ) do
    possible_statuses = [:pending_approval, :published, :draft]

    Implementation
    |> where([i], i.implementation_key == ^implementation_key)
    |> where([i], i.status in ^possible_statuses)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> changeset
      _ -> Changeset.add_error(changeset, :implementation_key, "duplicated")
    end
  end

  defp validate_implementation_key_is_not_used(changeset), do: changeset

  defp validate_content(%{} = changeset) do
    if template_name = get_field(changeset, :df_name) do
      changeset
      |> validate_required(:df_content)
      |> validate_change(:df_content, Validation.validator(template_name))
    else
      validate_change(changeset, :df_content, &empty_content_validator/2)
    end
  end

  defp empty_content_validator(_, value) when is_nil(value) or value == %{}, do: []
  defp empty_content_validator(field, _), do: [{field, "missing_type"}]

  defp validate_goal(%{valid?: true} = changeset) do
    minimum = get_field(changeset, :minimum)
    goal = get_field(changeset, :goal)
    result_type = get_field(changeset, :result_type)
    do_validate_goal(changeset, minimum, goal, result_type)
  end

  defp validate_goal(changeset), do: changeset

  defp do_validate_goal(changeset, minimum, goal, result_type)
       when result_type in ["percentage", "deviation"] do
    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> minimum_goal_check(minimum, goal, result_type)
  end

  defp do_validate_goal(changeset, minimum, goal, "errors_number") do
    changeset
    |> validate_number(:goal, greater_than_or_equal_to: 0)
    |> validate_number(:minimum, greater_than_or_equal_to: 0)
    |> minimum_goal_check(minimum, goal, "errors_number")
  end

  def minimum_goal_check(changeset, minimum, goal, "percentage") do
    case minimum <= goal do
      true -> changeset
      false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
    end
  end

  def minimum_goal_check(changeset, minimum, goal, result_type)
      when result_type in ["errors_number", "deviation"] do
    case minimum >= goal do
      true -> changeset
      false -> add_error(changeset, :minimum, "must.be.greater.than.or.equal.to.goal")
    end
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "default"}} = changeset,
         _implementation
       ) do
    default_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "raw"}} = changeset,
         _implementation
       ) do
    raw_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "basic"}} = changeset,
         _implementation
       ) do
    basic_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: "raw"}) do
    raw_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: "basic"}) do
    basic_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: _type}} = changeset,
         _implementation
       ) do
    default_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: _type}) do
    default_changeset(changeset)
  end

  defp raw_changeset(changeset) do
    maybe_cast_embed(changeset, :raw_content, with: &RawContent.changeset/2, required: true)
  end

  defp basic_changeset(changeset), do: changeset

  def default_changeset(changeset) do
    changeset
    |> maybe_cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> maybe_cast_embed(:populations, with: &Conditions.changeset/2)
    |> maybe_cast_embed(:validation, with: &Conditions.changeset/2, required: true)
    |> maybe_cast_embed(:segments, with: &SegmentsRow.changeset/2)
  end

  defp maybe_cast_embed(%{data: data} = changeset, field, opts) do
    cs = cast_embed(changeset, field, opts)

    original_value = Map.get(data, field)

    case Changeset.fetch_field(cs, field) do
      {:changes, ^original_value} -> changeset
      _ -> cs
    end
  end

  def get_execution_result_info(implementation, %{date: result_date} = result, %{
        type: "FAILED",
        inserted_at: event_date
      }) do
    case Date.compare(result_date, event_date) do
      :lt -> %{result_text: "quality_result.failed", date: event_date}
      _ -> get_execution_result_info(implementation, result, nil)
    end
  end

  def get_execution_result_info(_, nil, _), do: %{result_text: nil}

  def get_execution_result_info(implementation, result, _),
    do: build_result_info(implementation, result)

  defp build_result_info(%Implementation{result_type: result_type}, rule_result) do
    %{minimum: minimum, goal: goal} =
      result =
      Map.new()
      |> with_result(rule_result)
      |> with_date(rule_result)
      |> with_details(rule_result)
      |> with_thresholds(rule_result)

    result
    |> Helpers.with_result_text(minimum, goal, result_type)
  end

  defp with_result(result_map, rule_result) do
    rule_result
    |> Map.take([:result, :errors, :records])
    |> Map.merge(result_map)
  end

  defp with_date(result_map, rule_result) do
    Map.put(result_map, :date, Map.get(rule_result, :date))
  end

  defp with_details(result_map, %{details: %{} = details}) do
    Map.put(result_map, :details, details)
  end

  defp with_details(result_map, _), do: result_map

  defp with_thresholds(result_map, %{implementation_id: implementation_id}) do
    %{minimum: minimum, goal: goal} = TdDd.Repo.get(Implementation, implementation_id)

    Map.merge(%{minimum: minimum, goal: goal}, result_map)
  end

  def publishable?(%__MODULE__{status: status}), do: status in [:draft, :pending_approval]

  def restorable?(%__MODULE__{status: status, rule: %{deleted_at: nil}}),
    do: status == :deprecated

  def restorable?(%__MODULE__{status: status, rule: nil}), do: status == :deprecated

  def restorable?(%__MODULE__{}), do: false

  def versionable?(%__MODULE__{status: status} = implementation),
    do: Implementations.last?(implementation) && status == :published

  def deletable?(%__MODULE__{status: status}),
    do: status in [:draft, :pending_approval, :rejected, :deprecated]

  def editable?(%__MODULE__{status: status} = implementation),
    do: Implementations.last?(implementation) && status in [:draft, :rejected]

  def executable?(%__MODULE__{status: status, executable: executable}),
    do: status == :published && executable

  def submittable?(%__MODULE__{status: status}), do: status == :draft

  def rejectable?(%__MODULE__{status: status}), do: status == :pending_approval

  def convertible?(%__MODULE__{status: status})
      when status in [:deprecated, :versioned],
      do: false

  def convertible?(%__MODULE__{implementation_type: type}), do: type == "basic"
end
