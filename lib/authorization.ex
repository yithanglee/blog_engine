defmodule BlogEngine.Authorization do
  use Phoenix.Controller, namespace: BlogEngineWeb
  import Plug.Conn
  require IEx

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    if conn.request_path |> String.contains?("/admin") do
      if conn.private.plug_session["current_user"] == nil do
        cond do
          conn.request_path |> String.contains?("/login") ->
            conn

          conn.request_path |> String.contains?("/logout") ->
            conn

          conn.request_path |> String.contains?("/authenticate") ->
            conn

          true ->
            conn
            |> put_flash(:error, "You haven't login.")
            |> redirect(to: "/admin/login")
            |> halt
        end
      else
        conn
      end
    else
      if conn.request_path |> String.contains?("/0") do
        conn
        |> put_flash(:error, "Unauthorized.")
        |> redirect(to: "/admin")
        |> halt
      else
        conn
      end
    end
  end
end

defmodule BlogEngine.ApiAuthorization do
  @moduledoc """
  Validates `Authorization: Basic …` on POST (except listed public scopes).
  On success sets `conn.assigns.api_auth` to `{:member, map}` or `{:admin, username}` so
  downstream code does not re-parse the header.
  """
  use Phoenix.Controller, namespace: BlogEngineWeb
  import Plug.Conn
  require IEx

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    IO.inspect("call api auth")
    IO.inspect(conn.method)

    if conn.method == "POST" || conn.method == "OPTIONS" do
      cond do
        conn.params["scope"] in [
          "forgot_password_request",
          "list_organizations",
          "send_email_pin",
          "verify_email_pin",
          "verify_forgot_password_otp",
          "reset_password_with_token",
          "login",
          "member_sign_in",
          "override",
          "sign_in",
          "firebase_signin",
          "google_signin",
          "update_customer",
          "food_payment",
          "admin_menus",
          "customer_topup",
          "link_register",
          "checkout",
          "checkout_by_amount",
          "thank_you",
          "user_fcm_token"
        ] ->
          conn

        Plug.Conn.get_req_header(conn, "phx-request") != [] ->
          conn

        true ->
          with auth_token <- Plug.Conn.get_req_header(conn, "authorization") |> List.first(),
               true <- auth_token != nil,
               token <- auth_token |> String.split("Basic ") |> List.last(),
               t <- BlogEngine.Settings.decode_token(token) |> IO.inspect(),
               admin_t <-
                 BlogEngine.Settings.decode_admin_token(token)
                 |> IO.inspect() do
            conn =
              cond do
                t != nil ->
                  Plug.Conn.assign(conn, :api_auth, {:member, t})

                admin_t != nil ->
                  Plug.Conn.assign(conn, :api_auth, {:admin, admin_t})

                true ->
                  IO.inspect("not auth")

                  conn
                  |> resp(403, Jason.encode!(%{message: "Not authorized."}))
                  |> halt
              end

            conn
          else
            _ ->
              IO.inspect("not auth")

              conn
              |> resp(403, Jason.encode!(%{message: "Not authorized."}))
              |> halt
          end
      end
    else
      conn
    end
  end
end
