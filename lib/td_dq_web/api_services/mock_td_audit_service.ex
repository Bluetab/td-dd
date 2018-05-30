defmodule TdDqWeb.ApiServices.MockTdAuditService do
  @moduledoc false

  use Agent

  alias TdDq.Audit.Event

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: MockTdAuditService)
  end

  def post_audits(%{"audit" =>
                    %{"event" => event,
                      "payload" => payload,
                      "resource_id" => resource_id,
                      "resource_type" => resource_type,
                      "service" => service,
                      "ts" => ts,
                      "user_id" => user_id,
                      "user_name" => user_name}}) do
    new_event = %Event{id: Event.gen_id_from_event_ts(ts),
                       event: event,
                       payload: payload,
                       resource_id: resource_id,
                       resource_type: resource_type,
                       service: service,
                       ts: ts,
                       user_id: user_id,
                       user_name: user_name}
    Agent.update(MockTdAuditService, &(&1 ++ [new_event]))
    new_event
  end
end
