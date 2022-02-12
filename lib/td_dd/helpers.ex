defmodule TdDd.Helpers do
  @moduledoc """
  General functions
  """
  def shift_zone(date_utc_string, time_zone \\ Application.get_env(:td_dd, :time_zone))

  def shift_zone(nil, _time_zone) do
    nil
  end

  def shift_zone(date_utc_string, time_zone) do
    with {:ok, date_utc, _} <- DateTime.from_iso8601(date_utc_string),
         {:ok, datetime} <- DateTime.shift_zone(date_utc, time_zone) do
      DateTime.to_iso8601(datetime)
    else
      _error ->
        ""
    end
  end
end
