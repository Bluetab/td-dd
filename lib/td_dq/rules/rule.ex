defmodule TdDq.Rules.Rule do
  @moduledoc """
  Ecto Schema module for quality rules.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.TaxonomyCache
  alias TdDd.Repo
  alias TdDfLib.Validation
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  import Ecto.Query

  @type t :: %__MODULE__{}
  @inactive_implementation_status [
    :deprecated,
    :versioned
  ]

  schema "rules" do
    field(:business_concept_id, :integer)
    field(:active, :boolean, default: false)
    field(:deleted_at, :utc_datetime)
    field(:description, :map)
    field(:name, :string)
    field(:version, :integer, default: 1)
    field(:updated_by, :integer)
    field(:domain_id, :integer)
    field(:domain, :map, virtual: true)
    field(:df_name, :string)
    field(:df_content, :map)
    field(:template, :map, virtual: true)

    has_many(:rule_implementations, Implementation)
    has_many(:rule_results, RuleResult)

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = rule, %{} = params) do
    rule
    |> cast(params, [
      :business_concept_id,
      :active,
      :name,
      :deleted_at,
      :description,
      :version,
      :df_name,
      :df_content,
      :domain_id
    ])
    |> validate_required([:name, :domain_id], message: "required")
    |> validate_inclusion(:domain_id, TaxonomyCache.get_domain_ids())
    |> validate_change(:description, &Validation.validate_safe/2)
    |> validate_content(rule)
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_business_concept_id_name_index,
      message: "unique_constraint"
    )
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_name_index,
      message: "unique_constraint"
    )
  end

  def changeset(%__MODULE__{} = rule, params, updated_by) do
    rule
    |> changeset(params)
    |> put_change(:updated_by, updated_by)
  end

  def delete_changeset(%__MODULE__{} = rule) do
    rule
    |> changeset(%{active: false, deleted_at: DateTime.utc_now()})
    |> validate_inactive_implementations()
  end

  defp validate_content(%{valid?: true} = changeset, rule) do
    case get_field(changeset, :df_name) do
      nil ->
        validate_change(changeset, :df_content, empty_content_validator())

      template_name ->
        domain_id = get_field(changeset, :domain_id)

        changeset
        |> validate_required(:df_content)
        |> maybe_put_identifier(rule, template_name)
        |> validate_change(:df_content, Validation.validator(template_name, domain_id: domain_id))
    end
  end

  defp validate_content(changeset, _), do: changeset

  defp validate_inactive_implementations(%{data: %{id: rule_id}} = changeset) do
    %{active_implementations?: active_implementations?} =
      Implementation
      |> where([ri], ri.rule_id == ^rule_id and ri.status not in ^@inactive_implementation_status)
      |> select([ri], %{active_implementations?: count(ri) > 0})
      |> Repo.one

    if active_implementations? do
      add_error(changeset, :rule_implementations, "active_implementations")
    else
      changeset
    end
  end

  defp maybe_put_identifier(
         changeset,
         %{df_content: old_content},
         template_name
       ) do
    maybe_put_identifier_aux(changeset, old_content, template_name)
  end

  defp maybe_put_identifier(
         changeset,
         _,
         template_name
       ) do
    maybe_put_identifier_aux(changeset, %{}, template_name)
  end

  defp maybe_put_identifier_aux(
         %{valid?: true, changes: %{df_content: changeset_content}} = changeset,
         old_content,
         template_name
       ) do
    new_content =
      TdDfLib.Format.maybe_put_identifier(changeset_content, old_content, template_name)

    put_change(changeset, :df_content, new_content)
  end

  defp maybe_put_identifier_aux(changeset, _, _), do: changeset

  defp empty_content_validator do
    fn
      _, nil -> []
      _, value when value == %{} -> []
      field, _ -> [{field, :missing_type}]
    end
  end

  defimpl Elasticsearch.Document do
    alias TdCache.TemplateCache
    alias TdDfLib.Format
    alias TdDfLib.RichText
    alias TdDq.Rules.Rule
    alias TdDq.Search.Helpers

    @impl Elasticsearch.Document
    def id(%Rule{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Rule{domain_id: domain_id} = rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}
      updated_by = Helpers.get_user(rule.updated_by)
      confidential = Helpers.confidential?(rule)
      bcv = Helpers.get_business_concept_version(rule)
      domain = Helpers.get_domain(rule)
      domain_ids = List.wrap(domain_id)

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template, domain_id: domain_id)

      %{
        id: rule.id,
        business_concept_id: rule.business_concept_id,
        _confidential: confidential,
        domain: Map.take(domain, [:id, :external_id, :name]),
        domain_ids: domain_ids,
        current_business_concept_version: bcv,
        version: rule.version,
        name: rule.name,
        active: rule.active,
        description: RichText.to_plain_text(rule.description),
        deleted_at: rule.deleted_at,
        updated_by: updated_by,
        updated_at: rule.updated_at,
        inserted_at: rule.inserted_at,
        df_name: rule.df_name,
        df_label: Map.get(template, :label),
        df_content: df_content
      }
    end
  end
end
