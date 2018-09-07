defmodule TdDqWeb.RuleResultController do
  require Logger
  use TdDqWeb, :controller

  alias Ecto.Adapters.SQL
  alias TdDq.Repo
  alias TdDq.Rules

  @rules_results_query  ~S"""
    INSERT INTO rule_results ("business_concept_id", "rule", "system", "group", "structure_name", "field_name", "date", "result", inserted_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $7, $7)
  """
  @rule_results_param "rule_results"

  # TODO: tets this
  def upload(conn, params) do
    do_upload(conn, params)
    send_resp(conn, :ok, "")

  rescue e in RuntimeError ->
    Logger.error "While uploading #{e.message}"
    send_resp(conn, :unprocessable_entity, Poison.encode!(%{error: e.message}))
  end

  defp do_upload(conn, params) do

    Logger.info "Uploading rule results..."

    start_time = DateTime.utc_now()
    rules_results_upload = Map.get(params, @rule_results_param)
    Repo.transaction(fn ->
      upload_in_transaction(conn, rules_results_upload.path)
    end)
    end_time = DateTime.utc_now()

    Logger.info "Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"

  end

  defp upload_in_transaction(_conn, rules_results_upload_path) do

    Logger.info "Uploading rule results..."

    rules_results_upload_path
    |> File.stream!
    |> Stream.drop(1)
    |> CSV.decode!(separator: ?;)
    |> Enum.each(fn(data) ->
      data = List.update_at(data, 6, fn(x) -> Timex.to_datetime(Timex.parse!(x, "{YYYY}-{0M}-{D}")) end)
      data = List.update_at(data, 7, fn(x) -> String.to_integer(x) end)
      SQL.query!(Repo, @rules_results_query, data)
    end)
  end

  def index(conn, _params) do
    rules_results = Rules.list_rule_results()
    render(conn, "index.json", rule_results: rules_results)
  end

end
