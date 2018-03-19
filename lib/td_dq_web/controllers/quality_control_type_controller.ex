defmodule TdDqWeb.QualityControlTypeController do
  use TdDqWeb, :controller
  
  alias Poison, as: JSON

  action_fallback TdDqWeb.FallbackController

  def index(conn, _params) do
    quality_control_types = get_quality_control_types()
    render(conn, "index.json", quality_control_types: quality_control_types)
  end

  defp get_quality_control_types do
    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    file_path
    |> File.read!
    |> JSON.decode!
  end
end
