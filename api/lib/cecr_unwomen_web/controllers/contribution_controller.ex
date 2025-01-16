defmodule CecrUnwomenWeb.ContributionController do
  use CecrUnwomenWeb, :controller
  import Ecto.Query

  alias CecrUnwomenWeb.Models.{
    User,
    FirebaseToken,
    ScraperContribution,
    HouseholdContribution,
    OverallScraperContribution,
    OverallHouseholdContribution,
    HouseholdConstantFactor,
    ScrapConstantFactor
  }
  
  alias CecrUnwomen.Workers.FcmWorker
  alias CecrUnwomen.{Utils.Helper, Repo}

  def contribute_data(conn, params) do
    user_id = conn.assigns.user.user_id
    role_id = conn.assigns.user.role_id
    date = params["date"] |> Date.from_iso8601!()
    data_entry = params["data_entry"] || []

    res = cond do
      Enum.empty?(data_entry) -> Helper.response_json_message(false, "Không có thông tin để nhập", 406)

      role_id == 3 ->
        constant_value = GenServer.call(ConstantWorker, :get_scrap_factors)

        Repo.transaction(fn ->
          overall = Enum.reduce(data_entry, %{ kg_co2e_reduced: 0.0, expense_reduced: 0.0, kg_collected: 0.0 }, fn d, acc ->
            %{"factor_id" => factor_id, "quantity" => quantity} = d

            %ScraperContribution{
              date: date,
              user_id: user_id,
              factor_id: factor_id,
              quantity: :erlang.float(quantity)
            }
            |> Repo.insert()

            Map.update!(acc, :kg_collected, &(&1 + quantity))
            |> Map.update!(:kg_co2e_reduced, &(&1 + constant_value[factor_id] * quantity))
          end)

          overall = Map.update!(overall, :expense_reduced, &(&1 + constant_value[4] * overall.kg_collected))
          |> Enum.map(fn {k, v} -> {k, Float.round(v, 2)} end)
          |> Enum.into(%{})

          %OverallScraperContribution{
            date: date,
            user_id: user_id,
            kg_co2e_reduced: overall.kg_co2e_reduced,
            kg_collected: overall.kg_collected,
            expense_reduced: overall.expense_reduced
          } |> Repo.insert

          keys = ["kg_co2e_reduced", "expense_reduced", "kg_collected"]
          Helper.aggregate_with_fields(OverallScraperContribution, keys)
        end)
        |> case do
          {:ok, overall_data} -> 
            send_noti_to_admin(user_id, overall_data, date)
            Helper.response_json_with_data(true, "Nhập thông tin thành công!", overall_data)
            
          _ -> Helper.response_json_message(false, "Có lỗi xảy ra", 406)
        end

      role_id == 2 ->
        constant_value = GenServer.call(ConstantWorker, :get_household_factors)

        Repo.transaction(fn ->
          overall = Enum.reduce(data_entry, %{ kg_co2e_plastic_reduced: 0.0, kg_co2e_recycle_reduced: 0.0, kg_recycle_collected: 0.0}, fn d, acc ->
            %{"factor_id" => factor_id, "quantity" => quantity} = d
            # với factor_id từ 1 đến 4, là số lượng túi/giấy/ống hút => phải là int
            quantity = if factor_id <= 4, do: round(quantity), else: quantity

            %HouseholdContribution{
              date: date,
              user_id: user_id,
              factor_id: factor_id,
              quantity: :erlang.float(quantity)
            }
            |> Repo.insert()

            if (factor_id <= 4) do
              Map.update!(acc, :kg_co2e_plastic_reduced, &(&1 + constant_value[factor_id] * quantity))
            else
              Map.update!(acc, :kg_recycle_collected, &(&1 + quantity))
              |> Map.update!(:kg_co2e_recycle_reduced, &(&1 + constant_value[factor_id] * quantity))
            end
          end)
          |> Enum.map(fn {k, v} -> {k, Float.round(v, 2)} end)
          |> Enum.into(%{})

          %OverallHouseholdContribution{
            date: date,
            user_id: user_id,
            kg_co2e_plastic_reduced: overall.kg_co2e_plastic_reduced,
            kg_co2e_recycle_reduced: overall.kg_co2e_recycle_reduced,
            kg_recycle_collected: overall.kg_recycle_collected
          } |> Repo.insert

          keys = ["kg_co2e_plastic_reduced", "kg_co2e_recycle_reduced", "kg_recycle_collected"]
          Helper.aggregate_with_fields(OverallHouseholdContribution, keys)
        end)
        |> case do
          {:ok, overall_data} -> 
            send_noti_to_admin(user_id, overall_data, date)
            Helper.response_json_with_data(true, "Nhập thông tin thành công!", overall_data)
          _ -> Helper.response_json_message(false, "Có lỗi xảy ra", 406)
        end

      true -> Helper.response_json_message(false, "Có lỗi xảy ra khi thực hiện nhập thông tin!", 406)
    end

    json(conn, res)
  end
  
  defp send_noti_to_admin(user_id, data, date) do
    user_info = from(
      u in User,
      where: u.id == ^user_id,
      select: %{
        "first_name" => u.first_name,
        "last_name" => u.last_name,
        "role_id" => u.role_id,
        "avatar_url" => u.avatar_url
      }
    ) 
    |> Repo.one 
    
    admin_fcm_tokens = from(
      u in User,
      join: ft in FirebaseToken,
      on: u.id == ft.user_id,
      where: u.role_id == 1,
      select: %{
        "user_id" => u.id,
        "token" => ft.token,
      }
    )
    |> Repo.all
    # fold cac token thuoc cung 1 user lai ve 1 map 
    |> Helper.fold_fcm_token()
    
    Enum.each(admin_fcm_tokens, fn t -> 
      tokens = t["tokens"]
      date_string = Calendar.strftime(date, "%d/%m/%Y")
      user_name = "#{user_info["first_name"]} #{user_info["last_name"]}"
      role_name = if (user_info["role_id"] == 2), do: "hộ gia đình", else: "người thu gom"
      role_id = user_info["role_id"]
      avatar_url = user_info["avatar_url"]
        
      FcmWorker.send_firebase_notification(
        Enum.map(tokens, fn t -> %{"token" => t} end),
        %{
          "title" => "#{user_name} (#{role_name}) vừa nhập dữ liệu ngày #{date_string}",
          "body" => "Có dữ liệu đóng góp mới. Ấn vào thông báo để xem thông tin"
        },
        %{
          "type" => "user_contribute_data",
          "date" => date,
          "formatted_date" => date_string,
          "name" => user_name,
          "role_id" => role_id,
          "user_id" => user_id,
          "avatar_url" => avatar_url,
          "kg_co2e_reduced" => Map.get(data,:kg_co2e_reduced),
          "kg_collected" => Map.get(data,:kg_collected),
          "expense_reduced" => Map.get(data,:expense_reduced),
          "kg_co2e_plastic_reduced" => Map.get(data, :kg_co2e_plastic_reduced),
          "kg_co2e_recycle_reduced" => Map.get(data, :kg_co2e_recycle_reduced),
          "kg_recycle_collected" => Map.get(data,:kg_recycle_collected),
        }
      )
    end)
  end

  def edit_factor_quantity(conn, params) do
    user_id = conn.assigns.user.user_id
    factor_id = params["factor_id"] || 0
    quantity = params["quantity"] || 0
    type = params["type"] || "scrap"
    date = params["date"] |> Date.from_iso8601!()

    model = if type == "scrap", do: ScraperContribution, else: HouseholdContribution

    res =
      model
      |> where([m], m.user_id == ^user_id and m.factor_id == ^factor_id and m.date == ^date)
      |> select([m], m)
      |> Repo.one()
      |> case do
        nil ->
          Helper.response_json_message(false, "Bạn chưa nhập thông tin ngày hôm nay", 407)

        entry ->
          maximum_time_can_edit = entry.inserted_at |> NaiveDateTime.add(86400)
          can_edit = NaiveDateTime.utc_now() |> NaiveDateTime.before?(maximum_time_can_edit)

          if can_edit do
            data_changes = %{factor_id: factor_id, quantity: :erlang.float(quantity)}

            Ecto.Changeset.change(entry, data_changes)
            |> Repo.update()
            |> case do
              {:ok, updated_entry} ->
                key_drop =
                  if type == "scrap", do: :scrap_constant_factor, else: :household_constant_factor

                entry =
                  Map.from_struct(updated_entry)
                  |> Map.drop([:__meta__, :user, key_drop])
                  |> Enum.into(%{})

                Helper.response_json_with_data(true, "Cập nhật số liệu thành công!", entry)

              _ ->
                Helper.response_json_message(false, "Không thể update thông tin!", 407)
            end
          else
            Helper.response_json_message(false, "Không thể thay đổi thông tin sau 24h!", 408)
          end
      end

    json(conn, res)
  end

  def get_contribution(conn, params) do
    user_id_request = conn.assigns.user.user_id
    role_id_request = conn.assigns.user.role_id

    # business case
    # 1. admin query => k care user => check role_id
    # 2. user query => query chinh xac user => check role_id

    type = params["type"] || "scrap"
    limit = String.to_integer(params["limit"])
    page = String.to_integer(params["page"])
    offset = limit * page

    from = params["from"] |> Date.from_iso8601!()
    to = params["to"] |> Date.from_iso8601!()
    date_diff = Date.diff(from, to)

    is_admin = role_id_request == 1
    model = cond do
      is_admin -> if type == "scrap", do: ScraperContribution, else: HouseholdContribution
      role_id_request == 2 -> HouseholdContribution
      true -> ScraperContribution
    end

    res =
      cond do
        date_diff != 0 ->
          pre_query = if (is_admin) do
            model |> where([m], m.date >= ^from and m.date <= ^to)
          else
            model |> where([m], m.date >= ^from and m.date <= ^to and m.user_id == ^user_id_request)
          end
          data = pre_query
            |> order_by([m], desc: m.date)
            |> offset(^offset)
            |> limit(^limit)
            |> select([m], %{
              id: m.id,
              user_id: m.user_id,
              date: m.date,
              factor_id: m.factor_id,
              quantity: m.quantity,
              inserted_at: m.inserted_at
            })
            |> Repo.all()

          Helper.response_json_with_data(true, "Lấy dữ liệu thành công!", data)

        date_diff == 0 ->
          pre_query = if (is_admin) do
            model |> where([m], m.date == ^from)
          else
            model |> where([m], m.date == ^from and m.user_id == ^user_id_request)
          end
          data = pre_query
            |> order_by([m], desc: m.date)
            |> offset(^offset)
            |> limit(^limit)
            |> select([m], %{
              user_id: m.user_id,
              date: m.date,
              factor_id: m.factor_id,
              quantity: m.quantity,
              inserted_at: m.inserted_at
            })
            |> Repo.all()

          Helper.response_json_with_data(true, "Lấy dữ liệu thành công!", data)

        true -> Helper.response_json_message(false, "Có lỗi xảy ra!", 405)
      end

    json(conn, res)
  end

  def get_detail_contribution(conn, params) do
    user_id_request = conn.assigns.user.user_id
    role_id_request = conn.assigns.user.role_id
    user_id = params["user_id"]
    date = params["date"] |> Date.from_iso8601!()
    role_id = params["role_id"]

    res = cond do
      role_id_request == 1 ->
        model = if role_id == 2, do: HouseholdContribution, else: ScraperContribution
        data = model
          |> where([m], m.user_id == ^user_id and m.date == ^date)
          |> select([m], %{
            id: m.id,
            # user_id: m.user_id,
            date: m.date,
            factor_id: m.factor_id,
            quantity: m.quantity,
            # inserted_at: m.inserted_at
          })
          |> Repo.all()
          |> IO.inspect(label: "hehe")
        %{success: true, message: "Lấy dữ liệu thành công!", data: data}
      true ->
        is_same_user = user_id_request == user_id
        if is_same_user do
          model = if role_id_request == 2, do: HouseholdContribution, else: ScraperContribution
          data = model
            |> where([m], m.user_id == ^user_id_request and m.date == ^date)
            |> select([m], %{
              id: m.id,
              # user_id: m.user_id,
              date: m.date,
              factor_id: m.factor_id,
              quantity: m.quantity,
              # inserted_at: m.inserted_at
            })
            |> Repo.all()
            |> IO.inspect(label: "hehe")
          %{success: true, message: "Lấy dữ liệu thành công!", data: data}
        else
          %{success: false, message: "Bạn không có quyền xem thông tin này!", code: 402}
        end
    end
    json conn, res
  end

  def get_overall_data(conn, _) do
    # check role id
    # neu admin lay nhung data sau:
    # - scraper: total user, total kg collected, total kgco2 recycle, expense reduced
    # - household: total user, total kg recycled collected, total kgco2 recycle, plastic reduced
    # - data co2e recycled in 1 week from today
    # - household contribution today
    # - scraper contribution today
    user_id = conn.assigns.user.user_id
    role_id = conn.assigns.user.role_id
    res = cond do
      role_id != 1 ->
        model_overall = if role_id == 2, do: OverallHouseholdContribution, else: OverallScraperContribution
        keys = if role_id == 2, do: ["kg_co2e_plastic_reduced", "kg_co2e_recycle_reduced", "kg_recycle_collected"],
          else: ["kg_co2e_reduced", "expense_reduced", "kg_collected"]
        query = model_overall |> where([m], m.user_id == ^user_id)

        count_days_joined = User |> where([u], u.id == ^user_id) |> select([u], u.inserted_at) |> Repo.one
          |> case do
            nil -> 0
            inserted_at -> NaiveDateTime.utc_now() |> NaiveDateTime.diff(inserted_at, :day)
          end

        overall = Helper.aggregate_with_fields(query, keys)
          |> Map.put(:days_joined, count_days_joined)

        Helper.response_json_with_data(true, "Lấy dữ liệu thành công", overall)

      role_id == 1 ->
        keys = ["kg_co2e_plastic_reduced", "kg_co2e_recycle_reduced", "kg_recycle_collected"]
        count_household_user = User |> where([u], u.role_id == ^2) |> Repo.aggregate(:count)
        household_overall_data = Helper.aggregate_with_fields(OverallHouseholdContribution, keys) |> Map.put(:count_household, count_household_user)

        count_scraper_user = User |> where([u], u.role_id == ^3) |> Repo.aggregate(:count)
        keys = ["kg_co2e_reduced", "expense_reduced", "kg_collected"]
        scraper_overall_data = Helper.aggregate_with_fields(OverallScraperContribution, keys) |> Map.put(:count_scraper, count_scraper_user)

        {scraper_total_kgco2e_seven_days, household_total_kgco2e_seven_days} = get_total_kgco2e_seven_days()

        overall = %{
          household_overall_data: household_overall_data
            |> Map.put(:total_kgco2e_seven_days, household_total_kgco2e_seven_days),

          scraper_overall_data: scraper_overall_data
            |> Map.put(:total_kgco2e_seven_days, scraper_total_kgco2e_seven_days)
        }
        Helper.response_json_with_data(true, "Lấy dữ liệu thành công", overall)
      true ->
        Helper.response_json_message(false, "Bạn không có đủ quyền thực hiện thao tác!", 402)
    end
    json conn, res
  end

  def get_filter_overall_data(conn, params) do
    user_id = conn.assigns.user.user_id
    role_id = conn.assigns.user.role_id
    start_date = Date.from_iso8601!(params["start"])
    end_date =  Date.from_iso8601!(params["end"])
    
    res = cond do
      role_id != 1 ->
        sum_factors = if role_id == 2 do
          HouseholdContribution
          |> join(:inner, [hc], hcf in HouseholdConstantFactor, on: hc.factor_id == hcf.id)
          |> where([hc], hc.user_id == ^user_id and hc.date >= ^start_date and hc.date <= ^end_date)
          |> group_by([hc, hcf], [hc.factor_id, hcf.name])
        else
          ScraperContribution
          |> join(:inner, [hc], scf in ScrapConstantFactor, on: hc.factor_id == scf.id)
          |> where([hc], hc.user_id == ^user_id and hc.date >= ^start_date and hc.date <= ^end_date)
          |> group_by([hc, scf], [hc.factor_id, scf.name])
        end
        |> order_by([hc], asc: hc.factor_id)
        |> select([hc, f], %{
          factor_id: hc.factor_id,
          factor_name: f.name,
          quantity: sum(hc.quantity)
        })
        |> Repo.all
        
        overall_data_by_time = get_overall_contribution_by_time(user_id, role_id, start_date, end_date)
        overall = %{
          sum_factors: sum_factors,
          overall_data_by_time: overall_data_by_time
        }

        Helper.response_json_with_data(true, "Lấy dữ liệu thành công", overall)

      role_id == 1 ->
        {overall_scrapers_by_time, overall_households_by_time} = get_user_contributions_by_range(start_date, end_date)

        overall = %{
          household_overall_data: %{
            overall_data_by_time: overall_households_by_time
          },
          scraper_overall_data: %{
            overall_data_by_time: overall_scrapers_by_time
          }
        }
        Helper.response_json_with_data(true, "Lấy dữ liệu thành công", overall)
      true ->
        Helper.response_json_message(false, "Bạn không có đủ quyền thực hiện thao tác!", 402)
    end
    json conn, res
  end
  
  defp get_overall_contribution_by_time(user_id, role_id, start_date, end_date) do
    model_overall = if role_id == 2, do: OverallHouseholdContribution, else: OverallScraperContribution
    model_overall = model_overall
    |> where([m], m.user_id == ^user_id and m.date >= ^start_date and m.date <= ^end_date)
    |> order_by([m], desc: m.date)

    if role_id == 3 do
      model_overall
      |> select([m], %{
        id: m.id,
        date: m.date,
        kg_co2e_reduced: m.kg_co2e_reduced,
        expense_reduced: m.expense_reduced,
        kg_collected: m.kg_collected,
        inserted_at: m.inserted_at,
      })
    else
      model_overall
      |> select([m], %{
        id: m.id,
        date: m.date,
        kg_co2e_plastic_reduced: m.kg_co2e_plastic_reduced,
        kg_co2e_recycle_reduced: m.kg_co2e_recycle_reduced,
        kg_recycle_collected: m.kg_recycle_collected,
        inserted_at: m.inserted_at
      })
    end
    |> Repo.all
  end

  defp get_total_kgco2e_seven_days() do
    # to = "2024-11-11" |> Date.from_iso8601!()
    to = NaiveDateTime.local_now()
      |> NaiveDateTime.add(7 * 3600, :second)
      |> NaiveDateTime.to_date

    from = Date.add(to, -7)

    household_total_kgco2e_seven_days = OverallHouseholdContribution
      |> where([osc], osc.date >= ^from and osc.date <= ^to)
      |> group_by([m], m.date)
      |> order_by([m], desc: m.date)
      |> select([m], %{
        date: m.date,
        total_kg_co2e: sum(m.kg_co2e_plastic_reduced) + sum(m.kg_co2e_recycle_reduced)
      })
      |> Repo.all()

    scraper_total_kgco2e_seven_days = OverallScraperContribution
      |> where([osc], osc.date >= ^from and osc.date <= ^to)
      |> group_by([m], m.date)
      |> order_by([m], desc: m.date)
      |> select([m], %{
        date: m.date,
        total_kg_co2e: sum(m.kg_co2e_reduced)
      })
      |> Repo.all()

    {scraper_total_kgco2e_seven_days, household_total_kgco2e_seven_days}
  end

  defp get_user_contributions_by_range(start_date, end_date, limit \\ 50, page \\ 0) do
    offset = limit * page
    # current_day = NaiveDateTime.local_now()
    #   |> NaiveDateTime.add(7 * 3600, :second)
    #   |> NaiveDateTime.to_date

    overall_scrapers = OverallScraperContribution
      |> join(:left, [osc], u in User, on: u.id == osc.user_id)
      |> where([osc], osc.date >= ^start_date and osc.date <= ^end_date)
      |> order_by([osc], desc: :date)
      |> offset(^offset)
      |> limit(^limit)
      |> select([osc, u], %{
        id: osc.id,
        kg_co2e_reduced: osc.kg_co2e_reduced,
        expense_reduced: osc.expense_reduced,
        kg_collected: osc.kg_collected,
        user_id: osc.user_id,
        avatar_url: u.avatar_url,
        inserted_at: osc.inserted_at,
        date: osc.date,
        first_name: u.first_name,
        last_name: u.last_name
      })
      |> Repo.all

    overall_households = OverallHouseholdContribution
      |> join(:left, [ohc], u in User, on: u.id == ohc.user_id)
      |> where([osc], osc.date >= ^start_date and osc.date <= ^end_date)
      |> order_by([ohc], desc: :date)
      |> offset(^offset)
      |> limit(^limit)
      |> select([ohc, u], %{
        id: ohc.id,
        date: ohc.date,
        kg_co2e_plastic_reduced: ohc.kg_co2e_plastic_reduced,
        kg_co2e_recycle_reduced: ohc.kg_co2e_recycle_reduced,
        kg_recycle_collected: ohc.kg_recycle_collected,
        inserted_at: ohc.inserted_at,
        user_id: ohc.user_id,
        avatar_url: u.avatar_url,
        first_name: u.first_name,
        last_name: u.last_name
      })
      |> Repo.all

    {overall_scrapers, overall_households}
  end

end
