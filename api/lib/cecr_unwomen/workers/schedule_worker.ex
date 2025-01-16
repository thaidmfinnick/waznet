defmodule CecrUnwomen.Workers.ScheduleWorker do
  alias CecrUnwomen.Repo
  alias CecrUnwomen.Workers.FcmWorker
  alias CecrUnwomen.Utils.Helper
  alias CecrUnwomenWeb.Models.{
    OverallScraperContribution,
    OverallHouseholdContribution,
  }
  
  import Ecto.Query
  
  def schedule_to_send_noti_vi(data) do
    case AMQP.Application.get_channel(:default) do
      {:ok, channel} ->  Enum.map(data, fn u -> 
        hour = get_in(u, ["time_reminded","hour"])
        min = get_in(u, ["time_reminded","minute"])
        tokens = get_in(u, ["tokens"]) || ""
        user_id = get_in(u, ["user_id"])
        role_id = get_in(u, ["role_id"])
        
        if (hour == 0 && min == 0) do
          date = DateTime.now!("Asia/Ho_Chi_Minh") |> DateTime.to_date()
          
          contributed_data_today = case role_id do
            2 -> 
              from(
                ovr in OverallHouseholdContribution,
                where: ovr.date == ^date and ovr.user_id == ^user_id,
                select: count(ovr.id)
              ) |> Repo.one
              
            3 -> 
              from(
                ovr in OverallScraperContribution,
                where: ovr.date == ^date and ovr.user_id == ^user_id,
                select: count(ovr.id)
              ) |> Repo.one
          end
          
          if (contributed_data_today == 0) do
            local_time_string = Helper.get_local_time_now_string("Asia/Ho_Chi_Minh")
            FcmWorker.send_firebase_notification(
              Enum.map(tokens, fn t -> %{"token" => t} end),
              %{
                "title" => "Nhập dữ liệu ngày #{local_time_string}",
                "body" => "Bạn chưa nhập dữ liệu cho hôm nay. Ấn vào thông báo để tiến hành nhập liệu."
              },
              %{
                "type" => "remind_to_contribute",
                "role_id" => role_id
              }
            )
          end
        else 
          {queue_name, adjusted_time} = cond do
            hour > 12 -> 
              {"wait_hour_12", %{"hour" => hour - 12, "minute" => min}}
            
            hour > 0 -> 
              {"wait_hour_#{hour}", %{"hour" => 0, "minute" => min}}
            
            min > 30 -> 
              {"wait_min_30", %{"hour" => 0, "minute" => min - 30}}
            
            true -> 
              {"wait_min_#{min}", %{"hour" => 0, "minute" => 0}}
          end
          
          task = %{
            action: "broadcast_remind_to_input",
            data: %{
              "time_reminded" => adjusted_time,
              "tokens" => tokens,
              "user_id" => user_id,
              "role_id" => role_id
            }
          }
          AMQP.Basic.publish channel, "", queue_name, Jason.encode!(task), persistent: true
        end
        
      {:error, _} -> nil
      end)
    end
  end
end
