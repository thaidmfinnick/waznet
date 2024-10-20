defmodule CecrUnwomenWeb.UserController do
  use CecrUnwomenWeb, :controller
  alias CecrUnwomen.{Utils.Helper, Repo, RedisDB}
  alias CecrUnwomen.Models.{User}
  import Ecto.Query

  # plug CecrUnwomenWeb.AuthPlug when action not in [:register, :login]

  def register(conn, params) do
    phone_number = params["phone_number"]
    first_name = params["first_name"]
    last_name = params["last_name"]
    plain_password = params["password"]

    is_pass_phone_number = validate_phone_number_length(phone_number) && !has_user_with_phone_number(phone_number)
    is_pass_password = validate_password_length(plain_password)

    is_ready_to_insert = !is_nil(first_name) && !is_nil(last_name) && is_pass_password
    response = cond do
      !is_pass_phone_number -> Helper.response_json_message(false, "Số điện thoại không đúng hoặc đã tồn tại!", 279)
      !is_ready_to_insert -> Helper.response_json_message(false, "Bạn nhập thiếu các thông tin cần thiết! Vui lòng kiểm tra lại!", 301)
      true ->
        # TODO: validate role for admin
        init_role_id = 2
        user_id = Ecto.UUID.generate()
        password_hash = Argon2.hash_pwd_salt(plain_password)
        data_jwt = %{
          "user_id" => user_id,
          "role_id" => init_role_id
        }
        refresh_token = Helper.create_token(data_jwt, :refresh_token)
        access_token = Helper.create_token(data_jwt, :access_token)

        User.changeset(%User{}, %{
          id: user_id,
          first_name: first_name,
          last_name: last_name,
          role_id: init_role_id,
          phone_number: phone_number,
          password_hash: password_hash,
          refresh_token: refresh_token
        })
        |> Repo.insert
        |> case do
          {:ok, user} ->
            res_data = %{
              "access_token" => access_token,
              "refresh_token" => user.refresh_token,
              "user_id" => user.id,
              "role_id" => user.role_id,
              "first_name" => user.first_name,
              "last_name" => user.last_name
            }
            Helper.response_json_with_data(true, "Tạo tài khoản thành công", res_data)

          _ -> Helper.response_json_message(false, "Không thể tạo tài khoản, vui lòng liên hệ quản trị viên!", 300)
        end
    end

    json conn, response
  end

  def login(conn, params) do
    phone_number = params["phone_number"]
    plain_password = params["password"]

    is_pass_phone_number = validate_phone_number_length(phone_number) && has_user_with_phone_number(phone_number)
    is_pass_password_length = validate_password_length(plain_password)

    res = cond do
      !is_pass_phone_number -> Helper.response_json_message(false, "Không tìm thấy số điện thoại!", 280)
      !is_pass_password_length -> Helper.response_json_message(false, "Sai số điện thoại hoặc mật khẩu", 301)
      true ->
        from(u in User, where: u.phone_number == ^phone_number, select: u)
        |> Repo.one
        |> case do
          nil -> Helper.response_json_message(false, "Không tìm thấy tài khoản!", 302)
          user ->
            Argon2.verify_pass(plain_password, user.password_hash)
            |> case do
              false -> Helper.response_json_message(false, "Sai tài khoản hoặc mật khẩu!", 282)
              true ->
                data_jwt = %{
                  "user_id" => user.id,
                  "role_id" => user.role_id
                }
                refresh_token = Helper.create_token(data_jwt, :refresh_token)
                access_token = Helper.create_token(data_jwt, :access_token)

                Ecto.Changeset.change(user, %{refresh_token: refresh_token})
                |> Repo.update
                |> case do
                  {:ok, updated_user} ->
                    user_map = get_user_map_from_struct(updated_user)
                      # |> Map.drop([:location, :avatar_url, :date_of_birth, :email])
                    RedisDB.update_user(user_map)
                    res_data = %{
                      "access_token" => access_token,
                      "refresh_token" => updated_user.refresh_token,
                      "user_id" => user.id,
                      "role_id" => user.role_id,
                      "first_name" => user.first_name,
                      "last_name" => user.last_name
                    }
                    Helper.response_json_with_data(true, "Đăng nhập thành công", res_data)

                  _ -> Helper.response_json_message(false, "Có lỗi xảy ra!", 303)
                end

              _ -> Helper.response_json_message(false, "Có lỗi xảy ra!", 303)
            end
        end
    end

    json conn, res
  end

  def logout(conn, params) do
    user_id = params["user_id"]

    # TODO: add token to blacklist with redis
    res = Repo.get_by(User, id: user_id)
    |> case do
      nil -> Helper.response_json_message(false, "Không tìm thấy người dùng!", 300)
      user ->
        Ecto.Changeset.change(user, %{refresh_token: nil})
        |> Repo.update
        |> case do
          nil -> Helper.response_json_message(false, "Có lỗi xảy ra!", 303)
          _ ->
            Helper.response_json_message(true, "Đăng xuất thành công")
        end
    end
    json conn, res
  end


  def get_info(conn, params) do
    user_id = params["user_id"]

    response = RedisDB.get_user(user_id)
    |> case do
      nil ->
        Repo.get_by(User, id: user_id)
        |> case do
          nil -> Helper.response_json_message(false, "Không tìm thấy người dùng!", 300)
          user ->
            user_map = get_user_map_from_struct(user)
            Helper.response_json_with_data(true, "Lấy thông tin người dùng thành công", user_map)
        end
      user -> Helper.response_json_with_data(true, "Lấy thông tin người dùng thành công", user)
    end
    json conn, response
  end

  def get_user_map_from_struct(user) do
    Map.from_struct(user) |> Map.drop([:refresh_token, :inserted_at, :updated_at, :role, :__meta__, :password_hash])
  end

  def update_info(conn, params) do
    user_id = params["user_id"]
    res = Repo.get_by(User, id: user_id)
    |> case do
      nil -> Helper.response_json_message(false, "Không tìm thấy người dùng!", 300)
      user ->
        # first_name = params["first_name"]
        # last_name = params["last_name"]
        # avatar_url = params["avatar_url"]
        # date_of_birth = params["date_of_birth"]
        # email = params["email"]
        # gender = params["gender"]
        # location = params["location"]

        keys = ["first_name", "last_name", "avatar_url", "date_of_birth", "email", "gender", "location"]
        data_changes = Enum.reduce(keys, %{}, fn key, acc ->
          key_atom = String.to_atom(key)
          if params[key], do: Map.put(acc, key_atom, params[key])
        end)

        Ecto.Changeset.change(user, data_changes)
        |> Repo.update
        |> case do
          {:ok, updated_user} ->

          _ -> Helper.response_json_message(false, "Không thể cập nhật thông tin!", 321)
        end

    end
  end

  def change_password(conn, params) do
    user_id = conn.assigns.user.user_id
    old_password = params["old_password"]
    new_password = params["new_password"]

    response = Repo.get_by(User, id: user_id)
    |> case do
      nil -> Helper.response_json_message(false, "Không tìm thấy người dùng!", 300)

      user ->
        Argon2.verify_pass(old_password, user.password_hash)
        |> case do
          false -> Helper.response_json_message(false, "Sai tài khoản hoặc mật khẩu!", 282)
          true ->
            is_pass_password_length = validate_password_length(new_password)

            if is_pass_password_length do
              new_password_hash = Argon2.hash_pwd_salt(new_password)
              data_jwt = %{
                "user_id" => user_id,
                "role_id" => conn.assigns.user.role_id
              }

              new_refresh_token = Helper.create_token(data_jwt, :refresh_token)
              new_access_token = Helper.create_token(data_jwt, :access_token)
              Ecto.Changeset.change(user, %{password_hash: new_password_hash, refresh_token: new_refresh_token})
              |> Repo.update
              |> case do
                {:ok, _} ->
                  res_data = %{
                    "access_token" => new_access_token,
                    "refresh_token" => new_refresh_token
                  }
                  Helper.response_json_with_data(true, "Đổi mật khẩu thành công!", res_data)
                _ -> Helper.response_json_message(false, "Lỗi khi đổi mật khẩu")
              end
            else
              Helper.response_json_message(false, "Mật khẩu mới không được chấp nhận!", 282)
            end
        end
    end

    json conn, response
  end

  # def forgot_password(conn, params) do
  #   
  # end


  @spec validate_password_length(String.t()) :: boolean()
  defp validate_password_length(plain_password) do
    password_length = if is_nil(plain_password), do: -1, else: String.length(plain_password)
    if password_length < 8, do: false, else: true
  end

  defp has_user_with_phone_number(phone_number) do
    from(u in User, where: u.phone_number == ^phone_number)
    |> Repo.exists?()
  end

  defp validate_phone_number_length(phone_number) do
    phone_number_length = if is_nil(phone_number), do: -1, else: String.length(phone_number)
    if phone_number_length == 10, do: true, else: false
  end
end
