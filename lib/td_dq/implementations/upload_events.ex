defmodule TdDq.Implementations.UploadEvents do
  @moduledoc """
  File update Bulk Update Events
  """

  import Ecto.Query

  alias TdDd.Repo
  alias TdDq.Implementations.UploadEvent
  alias TdDq.Implementations.UploadJob

  def create_job(attrs) do
    %UploadJob{}
    |> UploadJob.changeset(attrs)
    |> Repo.insert()
  end

  def create_pending(job_id) do
    create_event(job_id, "PENDING")
  end

  def create_error(job_id, response) do
    create_event(job_id, "ERROR", response)
  end

  def create_info(job_id, response) do
    create_event(job_id, "INFO", response)
  end

  def create_failed(job_id, message) do
    create_event(job_id, "FAILED", %{message: message})
  end

  def create_started(job_id) do
    create_event(job_id, "STARTED")
  end

  def create_completed(job_id, response) do
    create_event(job_id, "COMPLETED", response)
  end

  defp create_event(job_id, status, response \\ %{}) do
    params =
      %{
        job_id: job_id,
        status: status,
        response: response
      }

    %UploadEvent{}
    |> UploadEvent.changeset(params)
    |> Repo.insert()
  end

  def list_jobs(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        user_id: nil,
        limit: 20,
        page: 0,
        order_by: :inserted_at,
        order_dir: :desc
      )

    limit = opts[:limit]
    offset = opts[:page] * limit
    allowed_fields = UploadJob.__schema__(:fields)
    field = if opts[:order_by] in allowed_fields, do: opts[:order_by], else: :inserted_at
    dir = if opts[:order_dir] in [:asc, :desc], do: opts[:order_dir], else: :desc

    latest_event_sq =
      from e in UploadEvent,
        where: e.job_id == parent_as(:job).id,
        order_by: [desc: e.inserted_at],
        limit: 1,
        select: %{status: e.status, response: e.response, inserted_at: e.inserted_at}

    from(j in UploadJob, as: :job)
    |> then(fn q ->
      case opts[:user_id] do
        nil -> q
        uid -> from j in q, where: j.user_id == ^uid
      end
    end)
    |> join(:left_lateral, [job: j], le in subquery(latest_event_sq), on: true)
    |> select_merge([_j, le], %{
      latest_status: le.status,
      latest_event_at: le.inserted_at,
      latest_event_response: le.response
    })
    |> order_by([j, _le], [{^dir, field(j, ^field)}])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def get_job(job_id) do
    latest_event_sq =
      from e in UploadEvent,
        where: e.job_id == parent_as(:job).id,
        order_by: [desc: e.inserted_at],
        limit: 1,
        select: %{status: e.status, response: e.response, inserted_at: e.inserted_at}

    job_query =
      from j in UploadJob,
        as: :job,
        where: j.id == ^job_id,
        left_lateral_join: le in subquery(latest_event_sq),
        on: true,
        preload: [events: ^from(e in UploadEvent, order_by: [asc: e.inserted_at])],
        select_merge: %{
          latest_status: le.status,
          latest_event_at: le.inserted_at,
          latest_event_response: le.response
        }

    Repo.one(job_query)
  end
end
