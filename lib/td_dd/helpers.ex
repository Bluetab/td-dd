defmodule TdDd.Helpers do
  @moduledoc """
  General functions
  """
  def shift_zone(date_utc_string, time_zone \\ Application.get_env(:td_dd, :time_zone))

  def shift_zone(nil, _time_zone), do: nil

  def shift_zone(%DateTime{} = datetime, time_zone) do
    case DateTime.shift_zone(datetime, time_zone) do
      {:ok, shifted} -> DateTime.to_iso8601(shifted)
      _error -> ""
    end
  end

  def shift_zone(date_utc_string, time_zone) when is_binary(date_utc_string) do
    with {:ok, date_utc, _} <- DateTime.from_iso8601(date_utc_string),
         {:ok, datetime} <- DateTime.shift_zone(date_utc, time_zone) do
      DateTime.to_iso8601(datetime)
    else
      _error -> ""
    end
  end

  def shift_zone(_, _), do: ""

  def binary_to_utc_date_time(time) do
    {:ok, time} = NaiveDateTime.from_iso8601(time)
    {:ok, time} = DateTime.from_naive(time, "Etc/UTC")
    time
  end
end
