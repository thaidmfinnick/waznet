defmodule CecrUnwomen.Workers.FcmWorker do
  alias CecrUnwomenWeb.Models.FirebaseToken
  alias CecrUnwomen. {Fcm.FcmPayload, Repo, Utils.ApiHandler}
  import Ecto.Query


  @url_firebase_messaging "https://fcm.googleapis.com/v1/projects/cecr-unwomen/messages:send"

  def send_firebase_notification(firebase_tokens, notification_field, data \\ %{}) do
    server_firebase_token = GenServer.call(FcmStore, :get_token)
    headers = [{"Authorization", "Bearer #{server_firebase_token}"}]

    # chú ý: đảm bảo key:value trong trường data (data_android/data_ios) phải là string:string, không sẽ báo lỗi k gửi được
    # data_android_string = data_android |> Map.new(fn {k, v} -> {k, to_string(v)} end)
    # data_ios_string = data_ios |> Map.new(fn {k, v} -> {k, to_string(v)} end)

    Enum.each(firebase_tokens, fn t ->
      token = t["token"]
      # payload = FcmPayload.create_payload(:both, token, notification_field)
      payload = cond do 
        data == %{} ->  FcmPayload.create_payload(:both, token, notification_field)
        true ->  
          data_valid = data |> Map.new(fn {k, v} -> {k, to_string(v)}  end)
          FcmPayload.create_payload_with_data(:both, token, notification_field, data_valid)
      end
      # payload = cond do
      #   t["platform"] == "android" -> FcmPayload.create_payload(:android, token, data_android_string)
      #   t["platform"] == "ios" && apns_custom_field != nil -> FcmPayload.create_payload(:ios_custom, token, data_ios_string, apns_custom_field)
      #   true -> FcmPayload.create_payload(:ios, token, notification_field, data_ios_string)
      # end

      if (token != nil), do: spawn(fn -> ApiHandler.post(:json, @url_firebase_messaging, payload, headers, []) end)
    end)

  rescue
    err -> IO.inspect(err, label: "error when send_firebase_notification_v2")
  end

  def send_test() do
    user_id = "f47cc61f-6e66-4822-835a-e0ed2485997e"
    query_firebase_tokens(:one, user_id) |> send_firebase_notification(%{
      "title" => "Test from CECR Unwomen server",
      "body" => "Welcome to CECR App"
    })
  end

  def query_firebase_tokens(:one, user_id_to_notify) do
    from(ft in FirebaseToken,
      where: ft.user_id == ^user_id_to_notify,
      select: %{
        "token" => ft.token,
        "user_id" => ft.user_id,
        "platform" => ft.platform
      }
    )
    |> Repo.all
    |> Enum.uniq
  end

  def query_firebase_tokens(:many, user_ids_to_notify) do
    from(ft in FirebaseToken,
      where: ft.user_id in ^user_ids_to_notify,
      select: %{
        "token" => ft.token,
        "user_id" => ft.user_id,
        "platform" => ft.platform
      }
    )
    |> Repo.all
    |> Enum.uniq
  end
end
