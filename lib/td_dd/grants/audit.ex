defmodule TdDd.Grants.Audit do
  @moduledoc """
  The Grants Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 5]

  alias TdCache.TaxonomyCache
  alias TdDd.Repo

  def grant_request_group_created(_repo, %{
        group: group
      }) do
    %{id: id, created_by_id: created_by_id, requests: requests} =
      Repo.preload(group, requests: [grant: [:data_structure], data_structure: [:current_version]])

    payload =
      Enum.reduce(
        requests,
        %{
          id: id,
          requests: take_from_grant_requests(requests)
        },
        fn request, acc_payload ->
          with_acc_domain_ids(acc_payload, request)
        end
      )

    publish("grant_request_group_creation", "grant_request_groups", id, created_by_id, payload)
  end

  defp take_from_grant_requests(requests) do
    Enum.map(
      requests,
      &take_from_grant_request/1
    )
  end

  defp take_from_grant_request(%{
         id: id,
         grant_id: grant_id
       })
       when not is_nil(grant_id) do
    %{
      id: id,
      grant_id: grant_id
    }
  end

  defp take_from_grant_request(%{
         id: id,
         data_structure: %{
           id: data_structure_id,
           current_version: %{name: name}
         }
       }) do
    %{
      id: id,
      data_structure: %{
        id: data_structure_id,
        current_version: %{name: name}
      }
    }
  end

  defp take_from_grant_request(%{
         id: id,
         data_structure: %{
           current_version: nil
         }
       }) do
    %{
      id: id,
      data_structure: %{
        current_version: nil
      }
    }
  end

  def grant_request_approval_created(_repo, %{
        approval: approval,
        status: grant_request_status
      }) do
    %{
      id: id,
      user_id: user_id,
      grant_request: grant_request,
      comment: comment
    } = Repo.preload(approval, grant_request: [:group, data_structure: :current_version])

    payload =
      %{
        grant_request: take_from_grant_request(grant_request),
        comment: comment,
        status: status_to_string(grant_request_status)
      }
      |> with_self_reported_recipient(grant_request_status, grant_request)
      |> with_domain_ids(grant_request)

    grant_request_status
    |> status_to_event_name
    |> publish("grant_request_approvals", id, user_id, payload)
  end

  def grant_request_approval_created(_repo, _multi) do
    {:ok, nil}
  end

  def grant_request_bulk_approval_created(
        _repo,
        %{approvals: {_, approvals}}
      )
      when approvals == [] do
    {:ok, []}
  end

  def grant_request_bulk_approval_created(
        _repo,
        %{approvals: {_, approvals}, statuses: {_, statuses}}
      ) do
    status_with_grant_id_index =
      Map.new(statuses, fn %{grant_request_id: grant_request_id} = status ->
        {grant_request_id, status}
      end)

    approvals
    |> Enum.map(fn approval ->
      status = Map.get(status_with_grant_id_index, approval.grant_request_id)
      grant_request_approval_created(nil, %{approval: approval, status: status})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: ids} -> {:ok, ids}
    end
  end

  def grant_request_status_created(_repo, %{
        grant_request_status: grant_request_status
      }) do
    %{id: id, user_id: user_id, status: status, grant_request: grant_request} =
      Repo.preload(grant_request_status, grant_request: [:group, data_structure: :current_version])

    payload =
      %{
        grant_request: take_from_grant_request(grant_request),
        status: status
      }
      |> with_domain_ids(grant_request)

    status
    |> status_name_to_event_name
    |> publish("grant_request_status", id, user_id, payload)
  end

  defp status_to_string(nil), do: "pending"
  defp status_to_string(%TdDd.Grants.GrantRequestStatus{status: status}), do: status

  defp status_to_event_name(nil), do: "grant_request_approval_addition"

  defp status_to_event_name(%TdDd.Grants.GrantRequestStatus{status: "approved"}),
    do: "grant_request_approval_consensus"

  defp status_to_event_name(%TdDd.Grants.GrantRequestStatus{status: "rejected"}),
    do: "grant_request_rejection"

  defp status_name_to_event_name("processing"), do: "grant_request_status_process_start"
  defp status_name_to_event_name("processed"), do: "grant_request_status_process_end"
  defp status_name_to_event_name("failed"), do: "grant_request_status_failure"
  defp status_name_to_event_name("cancelled"), do: "grant_request_status_cancellation"

  defp with_self_reported_recipient(
         payload,
         %TdDd.Grants.GrantRequestStatus{status: "rejected"} = _status,
         %{group: %{user_id: recipient_id}} = _grant_request
       ) do
    Map.put(payload, :recipient_ids, [recipient_id])
  end

  defp with_self_reported_recipient(payload, _status_, _grant_request), do: payload

  defp with_acc_domain_ids(%{domain_ids: acc_domain_ids} = payload, %{
         data_structure: %{domain_ids: domain_ids}
       }) do
    Map.put(payload, :domain_ids, acc_domain_ids ++ [get_domain_ids(domain_ids)])
  end

  defp with_acc_domain_ids(%{} = payload, %{grant: %{data_structure: %{domain_ids: domain_ids}}}) do
    Map.put(payload, :domain_ids, [get_domain_ids(domain_ids)])
  end

  defp with_acc_domain_ids(%{} = payload, %{data_structure: %{domain_ids: domain_ids}}) do
    Map.put(payload, :domain_ids, [get_domain_ids(domain_ids)])
  end

  defp with_domain_ids(%{} = payload, %{data_structure: %{domain_ids: domain_ids}}) do
    Map.put(payload, :domain_ids, get_domain_ids(domain_ids))
  end

  defp with_domain_ids(payload, _), do: payload

  defp get_domain_ids(nil), do: []
  defp get_domain_ids([]), do: []

  defp get_domain_ids(domain_ids) when is_list(domain_ids) do
    TaxonomyCache.reaching_domain_ids(domain_ids)
  end
end
