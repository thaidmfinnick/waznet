defmodule CecrUnwomenWeb.AuthPlug do
  use CecrUnwomenWeb, :controller
  alias CecrUnwomen. { Utils.ApiHandler, Utils.Helper }

  def init(_) do end

  def call(conn, _) do
    conn.req_headers
    |> Enum.find(fn {key, _value} -> key == "authorization" end)
    |> case do
      nil -> ApiHandler.send_conn_error(conn, "Không thể xác định người dùng!", 402)
      {"authorization", bearer} ->
        token = bearer |> String.split("Bearer ") |> List.last
        validate_and_assign_conn(conn, token)
    end
  end

  defp validate_and_assign_conn(conn, token) do
    Helper.validate_token(token)
    |> case do
      :invalid_token -> ApiHandler.send_conn_error(conn, "Không thể xác định người dùng!", 402)
      {:valid_token, data} -> assign(conn, :user, data)
    end
  end
end
