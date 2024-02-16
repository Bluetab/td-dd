defmodule TdDd.DataStructures.DataStructureLinks do
  @moduledoc """
  Ecto Schema module for Data Structure Link.
  """
  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureLinkLabel
  alias TdDd.DataStructures.Label
  alias TdDd.Repo
  alias TdDd.Utils.ChangesetUtils

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def links(%DataStructure{id: id}), do: all_by_id(id)

  def all_by(clauses) do
    DataStructureLink
    |> where(^clauses)
    |> Ecto.Query.preload([[source: :system], [target: :system], :labels])
    |> Repo.all()
  end

  def all_by_id(data_structure_id) do
    DataStructureLink
    |> where([dsl], dsl.source_id == ^data_structure_id or dsl.target_id == ^data_structure_id)
    |> Ecto.Query.preload([[source: :system], [target: :system], :labels])
    |> Repo.all()
  end

  def link_count(data_structure_id) do
    DataStructureLink
    |> where([dsl], dsl.source_id == ^data_structure_id or dsl.target_id == ^data_structure_id)
    |> select([dsl], count(dsl.source_id))
    |> Repo.one()
  end

  def get_by(%{
        "source_external_id" => source_external_id,
        "target_external_id" => target_external_id
      }) do
    DataStructureLink
    |> join(:inner, [dsl], ds_source in assoc(dsl, :source))
    |> join(:inner, [dsl], ds_target in assoc(dsl, :target))
    |> where(
      [dsl, ds_source, ds_target],
      ds_source.external_id == ^source_external_id and
        ds_target.external_id == ^target_external_id
    )
    |> Ecto.Query.preload([[source: :system], [target: :system], :labels])
    |> select([dsl, ds_source, ds_target], %DataStructureLink{
      dsl
      | source: ds_source,
        target: ds_target
    })
    |> Repo.one()
  end

  def get_by(%{"source_id" => source_id, "target_id" => target_id}) do
    get_by(%{source_id: source_id, target_id: target_id})
  end

  def get_by(%{source_id: source_id, target_id: target_id}) do
    DataStructureLink
    |> Ecto.Query.preload([[source: :system], [target: :system], :labels])
    |> Repo.get_by(source_id: source_id, target_id: target_id)
  end

  def all_by_external_id(external_id) do
    DataStructureLink
    |> join(:inner, [dsl], ds_source in assoc(dsl, :source))
    |> join(:inner, [dsl], ds_target in assoc(dsl, :target))
    |> where(
      [dsl, ds_source, ds_target],
      ds_source.external_id == ^external_id or ds_target.external_id == ^external_id
    )
    |> Ecto.Query.preload([[source: :system], [target: :system], :labels])
    |> Repo.all()
  end

  def validate_params(link_params) do
    case DataStructureLink.changeset_from_ids(link_params) do
      %Ecto.Changeset{valid?: false} = changeset ->
        {:error, changeset}

      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, changeset}
    end
  end

  def create_and_audit(%Changeset{} = changeset, user_id) do
    label_ids = Changeset.get_change(changeset, :label_ids, [])

    Multi.new()
    |> Multi.insert(
      :data_structure_link,
      changeset,
      on_conflict: {:replace, [:updated_at]},
      conflict_target: [:source_id, :target_id]
    )
    |> Multi.delete_all(
      :delete_old_dsl_label,
      fn %{
           data_structure_link: %{
             id: data_structure_link_id
           }
         } ->
        DataStructureLinkLabel
        |> where([dsl], dsl.data_structure_link_id == ^data_structure_link_id)
      end
    )
    |> Multi.insert_all(
      :insert_labels,
      DataStructureLinkLabel,
      fn %{
           data_structure_link: %{
             id: data_structure_link_id
           }
         } ->
        Enum.map(
          label_ids,
          fn label_id ->
            %{
              data_structure_link_id: data_structure_link_id,
              label_id: label_id
            }
          end
        )
      end,
      on_conflict: :nothing
    )
    |> Multi.run(:audit, Audit, :data_structure_link_created, [user_id])
    |> Repo.transaction()
  end

  def delete_and_audit(%DataStructureLink{} = link, user_id) do
    Multi.new()
    |> Multi.delete(
      :data_structure_link,
      link
    )
    |> Multi.run(:audit, Audit, :data_structure_link_deleted, [user_id])
    |> Repo.transaction()
  end

  def delete(%DataStructureLink{} = link) do
    Repo.delete(link)
  end

  def delete(source_id, target_id) do
    Repo.delete(%DataStructureLink{source_id: source_id, target_id: target_id})
  end

  def bulk_load(links) do
    Logger.info("Loading data structure links...")

    Timer.time(
      fn -> do_bulk_load(links) end,
      fn millis, _ -> Logger.info("Data structure links loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(links) do
    %{valid: valid_links, invalid: invalid_links} =
      links
      |> Enum.reduce(
        %{valid: MapSet.new(), invalid: MapSet.new()},
        fn link, %{valid: valid, invalid: invalid} = grouped_links ->
          case DataStructureLink.changeset(link) do
            %{
              valid?: true,
              changes: changes
            } ->
              %{
                grouped_links
                | valid: MapSet.put(valid, changes)
              }

            %{valid?: false} = changeset ->
              %{
                grouped_links
                | invalid: MapSet.put(invalid, %{invalid_link: link, changeset: changeset})
              }
          end
        end
      )

    %{source_external_ids: source_external_ids, target_external_ids: target_external_ids} =
      Enum.reduce(
        valid_links,
        %{source_external_ids: [], target_external_ids: []},
        fn %{
             source_external_id: source_external_id,
             target_external_id: target_external_id
           },
           %{
             source_external_ids: source_external_ids,
             target_external_ids: target_external_ids
           } ->
          %{
            source_external_ids: [source_external_id | source_external_ids],
            target_external_ids: [target_external_id | target_external_ids]
          }
        end
      )

    query_dsl =
      with_cte("input", "input",
        as:
          fragment(
            "select now() at time zone 'utc' as inserted_at, now() at time zone 'utc' as updated_at, source_external_id, target_external_id from unnest(?::text[], ?::text[]) as t(source_external_id, target_external_id)",
            ^source_external_ids,
            ^target_external_ids
          )
      )
      |> join(:inner, [input], ds_source in DataStructure,
        on: input.source_external_id == ds_source.external_id
      )
      |> join(:inner, [input], ds_target in DataStructure,
        on: input.target_external_id == ds_target.external_id
      )
      |> select(
        [input, ds_source, ds_target],
        %{
          source_id: ds_source.id,
          target_id: ds_target.id,
          source_external_id: input.source_external_id,
          target_external_id: input.target_external_id,
          inserted_at: input.inserted_at,
          updated_at: input.updated_at
        }
      )

    {:ok, transaction_value} =
      Multi.new()
      |> Multi.insert_all(:dsl, DataStructureLink, query_dsl,
        on_conflict: {:replace, [:updated_at]},
        conflict_target: [:source_id, :target_id],
        returning: true
      )
      |> Multi.run(
        :columns_dsls_labels,
        fn _repo, %{dsl: {_insert_links_count, inserted_links}} ->
          group_by =
            Enum.group_by(
              inserted_links ++ MapSet.to_list(valid_links),
              &Map.take(&1, [:source_external_id, :target_external_id])
            )
            |> Enum.reduce(
              %{label_names: [], data_structure_link_ids: []},
              &reduce_columns/2
            )

          {:ok, group_by}
        end
      )
      |> Multi.delete_all(
        :delete_old_dsl_label,
        fn %{
             columns_dsls_labels: %{
               data_structure_link_ids: data_structure_link_ids,
               label_names: _label_names
             }
           } ->
          DataStructureLinkLabel
          |> where([dsl], dsl.data_structure_link_id in ^data_structure_link_ids)
        end
      )
      |> Multi.insert_all(
        :insert_labels,
        DataStructureLinkLabel,
        fn %{
             columns_dsls_labels: %{
               data_structure_link_ids: data_structure_link_ids,
               label_names: label_names
             }
           } ->
          with_cte(
            "dsls_labels",
            "dsls_labels",
            as:
              fragment(
                "select data_structure_link_id, label_name from unnest(?::int[], ?::text[]) as t(data_structure_link_id, label_name)",
                ^data_structure_link_ids,
                ^label_names
              )
          )
          |> join(:inner, [dsls_labels], label in Label, on: dsls_labels.label_name == label.name)
          |> select([dsls_labels, label], %{
            data_structure_link_id: dsls_labels.data_structure_link_id,
            label_id: label.id
          })
        end,
        on_conflict: :nothing
      )
      |> Repo.transaction()

    %{dsl: {_inserted_links_count, inserted_links}} = transaction_value

    inserted_links_small =
      MapSet.new(inserted_links, fn link ->
        Map.take(link, [:source_external_id, :target_external_id])
      end)

    valid_links_small =
      MapSet.new(valid_links, fn link ->
        Map.take(link, [:source_external_id, :target_external_id])
      end)

    result = %{
      inserted: inserted_links_small,
      not_inserted: %{
        changeset_invalid_links:
          Enum.map(invalid_links, fn %{invalid_link: invalid_link, changeset: invalid_changeset} ->
            ChangesetUtils.error_message_list_on(invalid_changeset)
            |> Enum.map(fn %{field: field} = error_message ->
              Map.put(
                error_message,
                :value,
                Map.get(invalid_link, Atom.to_string(field))
              )
            end)
          end),
        inexistent_structure: MapSet.difference(valid_links_small, inserted_links_small)
      }
    }

    {:ok, result}
  end

  defp reduce_columns({_key, [%DataStructureLink{id: link_id}, %{label_names: label_names}]}, acc) do
    Enum.reduce(
      label_names,
      acc,
      fn label_name,
         %{
           label_names: acc_label_names,
           data_structure_link_ids: acc_data_structure_link_ids
         } ->
        %{
          acc
          | label_names: [label_name | acc_label_names],
            data_structure_link_ids: [link_id | acc_data_structure_link_ids]
        }
      end
    )
  end

  defp reduce_columns(_missing_link_or_label, acc), do: acc

  def create_label(params \\ %{}) do
    %Label{}
    |> Label.changeset(params)
    |> Repo.insert()
  end

  def list_labels do
    Repo.all(Label)
  end

  def get_label_by(%{"id" => id}) do
    Repo.get(Label, id)
  end

  def get_label_by(%{"name" => name}) do
    Repo.get_by(Label, name: name)
  end

  def delete_label(label) do
    Repo.delete(label)
  end
end
