defmodule TdDd.Helpers do

  @time_zone Application.get_env :td_dd, :time_zone

  def shift_zone(date_utc_string, time_zone \\ @time_zone)
  def shift_zone(nil, _time_zone) do
    nil
  end
  def shift_zone(date_utc_string, time_zone) do
    date_utc_string
    |> DateTime.from_iso8601
    |> (fn {:ok, date_utc, _} -> date_utc  end).()
    |> DateTime.shift_zone(time_zone)
    |> (fn {:ok, datetime} -> datetime end).()
    |> DateTime.to_iso8601
  end
end
