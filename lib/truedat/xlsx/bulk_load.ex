defmodule Truedat.XLSX.BulkLoad do
  @moduledoc """
  Generic XLSX bulk load.

  Dispatches to the appropriate BulkLoadProtocol implementation based on job scope.
  """

  alias TdDfLib.Format
  alias Truedat.Audit.UploadJobs
  alias Truedat.XLSX.BulkLoadProtocol

  require Logger

  def bulk_load(raw_sheets, ctx) do
    opts = BulkLoadProtocol.get_opts(ctx.impl_for)

    required_headers = Keyword.get(opts, :required_headers, [])
    discarded_headers = Keyword.get(opts, :discarded_headers, [])
    extra_headers = Keyword.get(opts, :extra_headers, [])
    translate_fn = Keyword.get(opts, :translate_fn, fn h, _ -> h end)

    translate = fn headers ->
      Enum.into(headers, %{}, &{translate_fn.(&1, ctx.lang) || &1, &1})
    end

    extra_context = Keyword.get(opts, :extra_context, %{})

    required_headers = translate.(required_headers)

    headers =
      extra_headers
      |> translate.()
      |> Map.merge(required_headers)

    discarded_headers = translate.(discarded_headers)

    headers_ctx =
      ctx
      |> Map.merge(%{
        required_headers: required_headers,
        headers: headers,
        discarded_headers: discarded_headers
      })

    {valid_sheets, invalid_sheet_count} = validate_sheets_headers(raw_sheets, headers_ctx)

    params = parse_sheets(valid_sheets, headers_ctx)

    ctx =
      valid_sheets
      |> Enum.map(&elem(&1, 0))
      |> then(&BulkLoadProtocol.sheets_to_templates(ctx.impl_for, &1))
      |> parse_templates(ctx.lang)
      |> then(&Map.put(ctx, :templates, &1))
      |> Map.merge(extra_context)

    {inserted_ids, updated_ids, error_count, unchanged_count} =
      params
      |> Enum.reduce(
        {[], [], 0, 0},
        fn item, {ids, updated_ids, errors, unchanged_count} ->
          case BulkLoadProtocol.bulk_load_item(ctx.impl_for, item, ctx) do
            {:error, {type, details}} ->
              UploadJobs.create_error(ctx.job_id, %{
                type: type,
                sheet: item["_sheet"],
                row_number: item["_row_number"],
                details: details
              })

              {ids, updated_ids, errors + 1, unchanged_count}

            {:unchanged, details} ->
              UploadJobs.create_info(ctx.job_id, %{
                type: "unchanged",
                sheet: item["_sheet"],
                row_number: item["_row_number"],
                details: details
              })

              {ids, updated_ids, errors, unchanged_count + 1}

            {:created, {id, details}} ->
              UploadJobs.create_info(ctx.job_id, %{
                type: "created",
                sheet: item["_sheet"],
                row_number: item["_row_number"],
                details: details
              })

              {[id | ids], updated_ids, errors, unchanged_count}

            {:updated, {id, details}} ->
              UploadJobs.create_info(ctx.job_id, %{
                type: "updated",
                sheet: item["_sheet"],
                row_number: item["_row_number"],
                details: details
              })

              {ids, [id | updated_ids], errors, unchanged_count}
          end
        end
      )

    all_ids = inserted_ids ++ updated_ids

    if all_ids != [] do
      BulkLoadProtocol.on_complete(ctx.impl_for, all_ids)
    end

    {:ok,
     %{
       insert_count: length(inserted_ids),
       update_count: length(updated_ids),
       error_count: error_count,
       unchanged_count: unchanged_count,
       invalid_sheet_count: invalid_sheet_count
     }}
  end

  defp validate_sheets_headers(sheets, ctx) do
    Enum.reduce(sheets, {[], 0}, fn {sheet_name, {headers, _rows}} = sheet,
                                    {valid_sheets, invalid_count} ->
      if validate_sheet_headers(sheet_name, headers, ctx) do
        {valid_sheets ++ [sheet], invalid_count}
      else
        {valid_sheets, invalid_count + 1}
      end
    end)
  end

  defp validate_sheet_headers(sheet_name, headers, ctx) do
    ctx.required_headers
    |> Map.keys()
    |> Enum.reject(&Enum.member?(headers, &1))
    |> case do
      [] ->
        true

      missing_headers ->
        UploadJobs.create_error(ctx.job_id, %{
          type: "missing_required_headers",
          sheet: sheet_name,
          details: %{missing_headers: missing_headers}
        })

        false
    end
  end

  defp parse_sheets(sheets, ctx) do
    sheets
    |> Enum.flat_map(&parse_sheet(&1, ctx))
    |> List.flatten()
  end

  defp parse_sheet({sheet_name, {headers, rows}}, ctx) do
    {base_headers, df_headers} =
      headers
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {header, idx} = value, {headers, df_headers} ->
        cond do
          Map.has_key?(ctx.discarded_headers, header) ->
            {headers, df_headers}

          Map.has_key?(ctx.headers, header) ->
            {[{Map.get(ctx.headers, header), idx} | headers], df_headers}

          true ->
            {headers, [value | df_headers]}
        end
      end)

    Enum.with_index(rows, fn row, index ->
      df_content =
        Enum.into(df_headers, %{}, fn {header, idx} ->
          value = Enum.at(row, idx)
          {header, %{"value" => value, "origin" => "file"}}
        end)

      base_headers
      |> Enum.into(%{}, fn {header, idx} ->
        {header, Enum.at(row, idx)}
      end)
      |> Map.merge(%{
        "df_content" => df_content,
        "_sheet" => sheet_name,
        "_row_number" => index + 2
      })
    end)
  end

  defp parse_templates(templates, lang) do
    Enum.into(templates, %{}, fn {df_name, template} ->
      content_schema = Format.flatten_content_fields(template.content, lang)
      translations = Enum.into(content_schema, %{}, &{&1["definition"], &1["name"]})

      {df_name, %{template: template, translations: translations, content_schema: content_schema}}
    end)
  end
end
