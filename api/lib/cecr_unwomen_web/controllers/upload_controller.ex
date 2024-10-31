defmodule CecrUnwomenWeb.UploadController do
  alias CecrUnwomen.Utils.Helper
  use CecrUnwomenWeb, :controller

  def upload_avatar(conn, params) do
    user_id = conn.assigns.user.user_id
    data_image = params["data"]
    content_type = data_image.content_type
    path = data_image.path
    file_name = data_image.filename

    can_serve = content_type != nil && path != nil && file_name != nil
    res = if (!can_serve) do
      Helper.response_json_message(false, "Ảnh không hợp lệ!", 300)
    else
      extension = Path.extname(file_name)
      is_image = extension |> String.downcase |> String.contains?(["jpg", "png", "heic", "jpeg"])

      cond do
        !is_image -> Helper.response_json_message(false, "Bạn upload không đúng định dạng!", 402)
        true ->
          image_avatar_name = "#{user_id}_avatar#{extension}"
          destination = "/Users/admin/Desktop/#{image_avatar_name}"
          File.cp(path, destination)
          |> case do
            :ok ->
              # save to db and redis
              Helper.response_json_message(true, "Upload avatar thành công")
            {:error, err} ->
              IO.inspect(err, label: "e")
              Helper.response_json_message(false, "Không thể lưu ảnh!", 402)
          end
        end
    end
    json conn, res
  end
end