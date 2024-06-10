defmodule RevenueMonster do
  require Logger
  @key Application.get_env(:blog_engine, :revenue_monster)[:key]
  @endpoint Application.get_env(:blog_engine, :revenue_monster)[:endpoint]
  @auth [hackney: [basic_auth: {@key, ""}]]
  @callback_url Application.get_env(:blog_engine, :revenue_monster)[:callback]
  @redirect_url Application.get_env(:blog_engine, :url)

  def query_map(checkout_id) do
    %{
      "checkoutId" => checkout_id
    }
    |> Jason.encode!()
  end

  def plain_text_params_query(
        checkout_id,
        ts \\ 1_527_407_052,
        nonce_string \\ "VYNknZohxwicZMaWbNdBKUrnrxDtaRhN"
      ) do
    "data=#{query_map(checkout_id) |> Base.encode64()}&method=get&nonceStr=#{nonce_string}&requestUrl=#{Application.get_env(:blog_engine, :revenue_monster)[:endpoint] <> ""}&signType=sha256&timestamp=#{ts}"
  end

  def direct_checkout_map(checkout_id) do
    %{
      "checkoutId" => checkout_id,
      "type" => "QRCODE",
      "method" => "MAYBANK_MY"
    }
    |> Jason.encode!()
  end

  def plain_text_params_direct_checkout(
        checkout_id,
        ts \\ 1_527_407_052,
        nonce_string \\ "VYNknZohxwicZMaWbNdBKUrnrxDtaRhN"
      ) do
    "data=#{direct_checkout_map(checkout_id) |> Base.encode64()}&method=post&nonceStr=#{nonce_string}&requestUrl=#{Application.get_env(:blog_engine, :revenue_monster)[:endpoint] <> "/checkout"}&signType=sha256&timestamp=#{ts}"
  end

  def map(store_id, sales_id, amount_in_cents, title) do
    additional_data = title
    amount = amount_in_cents
    id = sales_id

    port =
      Application.get_env(:blog_engine, BlogEngineWeb.Endpoint)
      |> Enum.into(%{})
      |> Map.get(:http)
      |> Enum.into(%{})
      |> Map.get(:port)

    host =
      Application.get_env(:blog_engine, BlogEngineWeb.Endpoint)[:url]
      |> Enum.into(%{})
      |> Map.get(:host)

    host =
      if host == "localhost" do
        "http://localhost:#{port}"
      else
        "https://#{host}"
      end

    redirect_url = "#{host}/thank_you"

    notify_url =
      "#{Application.get_env(:blog_engine, :revenue_monster)[:callback]}/api/payment/billplz"

    %{
      "order" => %{
        "title" => "#{title}",
        "detail" => "",
        "additionalData" => "#{additional_data}",
        "amount" => amount,
        "currencyType" => "MYR",
        "id" => "#{id}"
      },
      "customer" => %{
        "userId" => "13245876",
        "email" => ""
      },
      "method" => [],
      "type" => "WEB_PAYMENT",
      "storeId" => "#{store_id}",
      "redirectUrl" => "#{redirect_url}",
      "notifyUrl" => "#{notify_url}",
      "layoutVersion" => "v4"
    }
    |> Jason.encode!()
  end

  def plain_text_params(
        store_id,
        sales_id,
        amount_in_cents,
        title,
        ts \\ 1_527_407_052,
        nonce_string \\ "VYNknZohxwicZMaWbNdBKUrnrxDtaRhN"
      ) do
    "data=#{map(store_id, sales_id, amount_in_cents, title) |> Base.encode64()}&method=post&nonceStr=#{nonce_string}&requestUrl=#{Application.get_env(:blog_engine, :revenue_monster)[:endpoint]}&signType=sha256&timestamp=#{ts}"
  end

  def credentials() do
    url = Application.get_env(:blog_engine, :revenue_monster)[:oauth]
    client_id = Application.get_env(:blog_engine, :revenue_monster)[:client_id]
    client_secret = Application.get_env(:blog_engine, :revenue_monster)[:client_secret]
    body = %{"grantType" => "client_credentials"}
    struc = "#{client_id}:#{client_secret}"
    b64 = struc |> Base.encode64()

    case HTTPoison.post(
           url,
           Jason.encode!(body),
           [{"Content-Type", "application/json"}, {"Authorization", "Basic #{b64}"}]
         ) do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            nil
            res |> IO.inspect()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def pk(data) do
    app_dir = Application.app_dir(:blog_engine)
    path = app_dir <> Application.get_env(:blog_engine, :revenue_monster)[:cert_location]

    rsa_priv_key = ExPublicKey.load!(path)

    {:ok, signature} = ExPublicKey.sign(data, rsa_priv_key)

    encoded_signature = Base.encode64(signature)
  end

  def query_transaction(checkout_id) do
    # get
    url = Application.get_env(:blog_engine, :revenue_monster)[:endpoint] <> ""

    ts = DateTime.utc_now() |> DateTime.to_unix()
    at = RevenueMonster.credentials() |> Map.get("accessToken")
    nonce_string = "65ed7033b7505223a6e279e31c7e9487aab92ddccc516c35598d521591770a3f"

    signature =
      plain_text_params_query(checkout_id, ts, nonce_string)
      |> IO.inspect()
      |> pk()
      |> IO.inspect()

    # HTTPoison.request(:get, url, Jason.encode!(json_body), headers, options)
    case HTTPoison.request(
           :get,
           url,
           query_map(checkout_id),
           [
             {"Content-Type", "application/json"},
             {"Authorization", "Bearer #{at}"},
             {"X-Nonce-Str", nonce_string},
             {"X-Signature", "sha256 #{signature}"},
             {"X-Timestamp", ts}
           ]
         )
         |> IO.inspect() do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            nil
            res |> IO.inspect()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def direct_checkout(checkout_id) do
    url = Application.get_env(:blog_engine, :revenue_monster)[:endpoint] <> "/checkout"

    ts = DateTime.utc_now() |> DateTime.to_unix()

    at = RevenueMonster.credentials() |> Map.get("accessToken")
    nonce_string = "65ed7033b7505223a6e279e31c7e9487aab92ddccc516c35598d521591770a3f"

    signature =
      plain_text_params_direct_checkout(checkout_id, ts, nonce_string)
      |> IO.inspect()
      |> pk()
      |> IO.inspect()

    case HTTPoison.post(
           url,
           direct_checkout_map(checkout_id),
           [
             {"Content-Type", "application/json"},
             {"Authorization", "Bearer #{at}"},
             {"X-Nonce-Str", nonce_string},
             {"X-Signature", "sha256 #{signature}"},
             {"X-Timestamp", ts}
           ]
         )
         |> IO.inspect() do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            nil
            res |> IO.inspect()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def pay(store_id \\ 1_714_210_689_792_712_093, sales_id, amount_in_cents, title) do
    ts = DateTime.utc_now() |> DateTime.to_unix()

    at = RevenueMonster.credentials() |> Map.get("accessToken")
    nonce_string = "65ed7033b7505223a6e279e31c7e9487aab92ddccc516c35598d521591770a3f"

    signature =
      plain_text_params(store_id, sales_id, amount_in_cents, title, ts, nonce_string)
      |> IO.inspect()
      |> pk()
      |> IO.inspect()

    url = Application.get_env(:blog_engine, :revenue_monster)[:endpoint]

    case HTTPoison.post(
           url,
           map(store_id, sales_id, amount_in_cents, title),
           [
             {"Content-Type", "application/json"},
             {"Authorization", "Bearer #{at}"},
             {"X-Nonce-Str", nonce_string},
             {"X-Signature", "sha256 #{signature}"},
             {"X-Timestamp", ts}
           ]
         )
         |> IO.inspect() do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            nil
            res |> IO.inspect()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
