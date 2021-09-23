defmodule TdCx.Audit.Event do
  @moduledoc false
  defstruct id: 0,
            event: nil,
            payload: %{},
            resource_id: nil,
            resource_type: nil,
            service: nil,
            ts: nil,
            user_id: nil,
            user_name: nil

  def gen_id_from_event_ts(ts) do
    Integer.mod(:binary.decode_unsigned(ts), 100_000)
  end
end
