defmodule CecrUnwomen.Fcm.FcmPayload do
    def create_payload_with_data(:both, token, notification, data) do
      %{
        "message" => %{
          "token" => token,
          "notification" => notification,
          "data" => data
        },
      }
    end
    
    def create_payload(:both, token, notification) do
      %{
        "message" => %{
          "token" => token,
          "notification" => notification,
        }
      }
    end

    # https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#AndroidNotification
    def create_payload(:android, token, data) do
      %{
        "message" => %{
          "token" => token,
          "android" => %{
            "priority" => "normal",
            "notification" => data
          }
        }
      }
    end

    def create_payload(:ios, token, notification, data) do
      %{
        "message" => %{
          "token" => token,
          "data" => data,
          "apns" => %{
            "payload" => %{
              "aps" => %{
                "alert" => %{} |> Map.merge(notification),
              }
            }
          }
        }
      }
    end

    # fields khi bắn noti custom (noti với badge, sound, hoặc silent)
    # các trường trong apns xem ở link:
    # https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification
    # https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#apnsconfig
    def create_payload(:ios_custom, token, data, apns_field) do
      %{
        "message" => %{
          "token" => token,
          "data" => data,
          "apns" => apns_field
        }
      }
    end
end
