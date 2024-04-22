defmodule Billplz do
  require Logger
  @key Application.get_env(:blog_engine, :billplz)[:key]
  @endpoint Application.get_env(:blog_engine, :billplz)[:endpoint]
  @auth [hackney: [basic_auth: {@key, ""}]]
  @callback_url Application.get_env(:blog_engine, :billplz)[:callback]
  @redirect_url Application.get_env(:blog_engine, :url)

  def get_bill(bill_id) do
    url = @endpoint <> "v3/bills/#{bill_id}"

    Logger.info("[billplz] - get bill...")

    with {:ok,
          %HTTPoison.Response{
            body: body,
            status_code: 200
          }} <-
           HTTPoison.get(
             url,
             [{"Content-Type", "application/json"}],
             @auth
           )
           |> IO.inspect(),
         {:ok, res} <- Jason.decode(body) |> IO.inspect() do
      res
    else
      _ ->
        %{}
    end
  end

  @doc """
  Billplz.create_open_collection("wetml7wi")
  """
  def create_bill(collection_id, %{
        description: description,
        email: email,
        name: name,
        amount: amount,
        phone: phone
      }) do
    url = @endpoint <> "v3/bills"

    case HTTPoison.post(
           url,
           Jason.encode!(%{
             collection_id: collection_id,
             email: email,
             mobile: phone,
             name: name,
             amount: (amount * 100) |> :erlang.trunc(),
             callback_url: @callback_url,
             description: description,
             redirect_url: @redirect_url <> "/thank_you"
           }),
           [{"Content-Type", "application/json"}],
           @auth
         ) do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            IO.inspect(res)

            sample = %{
              "amount" => 23540,
              "callback_url" => "https://f770-115-164-46-61.ngrok-free.app/api/webhook",
              "collection_id" => "dpmor8lq",
              "description" => "register in haho",
              "due_at" => "2023-11-17",
              "email" => "robert_seo@gmail.com",
              "id" => "w0oly520",
              "mobile" => nil,
              "name" => "ROBERT LIM",
              "paid" => false,
              "paid_amount" => 0,
              "paid_at" => nil,
              "redirect_url" => nil,
              "reference_1" => "BP-FKR01",
              "reference_1_label" => "Bank Code",
              "reference_2" => nil,
              "reference_2_label" => "Reference 2",
              "state" => "due",
              "url" => "https://www.billplz-sandbox.com/bills/w0oly520"
            }

            res

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Billplz.create_open_collection("wetml7wi")
  """
  def create_open_collection(title, description, amount) do
    url = @endpoint <> "v4/open_collections"

    case HTTPoison.post(
           url,
           Jason.encode!(%{
             title: title,
             description: description,
             amount: (amount * 100) |> :erlang.trunc()
           }),
           [{"Content-Type", "application/json"}],
           @auth
         ) do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            IO.inspect(res)

            sample = %{
              "amount" => 23450,
              "description" => "order haho",
              "email_link" => nil,
              "fixed_amount" => true,
              "fixed_quantity" => true,
              "id" => "sg7pr_id",
              "payment_button" => "pay",
              "photo" => %{"avatar_url" => nil, "retina_url" => nil},
              "redirect_uri" => nil,
              "reference_1_label" => nil,
              "reference_2_label" => nil,
              "split_header" => false,
              "split_payments" => [],
              "tax" => nil,
              "title" => "FIRST COLLECTION FOR DAMIEN",
              "url" => "https://www.billplz-sandbox.com/sg7pr_id"
            }

            res

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def save_channels(res) do
    gateways = Map.get(res, "payment_gateways", [])

    for gateway <- gateways do
      BlogEngine.Settings.create_payment_channel(gateway)
    end

    res
  end

  @doc """
  call this only every hour
  """
  def get_payment_channels() do
    url = @endpoint <> "v4/payment_gateways"

    with {:ok,
          %HTTPoison.Response{
            body: body,
            status_code: 200
          }} <-
           HTTPoison.get(
             url,
             [{"Content-Type", "application/json"}],
             @auth
           ),
         {:ok, res} <- Jason.decode(body) do
      res |> save_channels
    else
      _ ->
        []
    end
  end

  @doc """
  Billplz.direct_payment("wetml7wi", "yithanglee@gmail.com", "DAMIEN LEE", 223.50, "MBB", "Testing charge")

  https://www.billplz-sandbox.com/bills/vcs0gjwv?auto_submit=true
  """
  def direct_payment(collection_id, email, name, amount, bank_code, description) do
    url = @endpoint <> "v3/bills"

    case HTTPoison.post(
           url,
           Jason.encode!(%{
             collection_id: collection_id,
             email: email,
             name: name,
             amount: (amount * 100) |> :erlang.trunc(),
             reference_1_label: "Bank Code",
             reference_1: "BP-FKR01",
             callback_url: @callback_url,
             description: description
           }),
           [{"Content-Type", "application/json"}],
           @auth
         ) do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            IO.inspect(res)

            sample = %{
              "amount" => 22350,
              "callback_url" => "http://localhost:4000/api/webhook",
              "collection_id" => "wetml7wi",
              "description" => "Testing charge",
              "due_at" => "2023-11-17",
              "email" => "yithanglee@gmail.com",
              "id" => "vcs0gjwv",
              "mobile" => nil,
              "name" => "DAMIEN LEE",
              "paid" => false,
              "paid_amount" => 0,
              "paid_at" => nil,
              "redirect_url" => nil,
              "reference_1" => "BP-FKR01",
              "reference_1_label" => "Bank Code",
              "reference_2" => nil,
              "reference_2_label" => "Reference 2",
              "state" => "due",
              "url" => "https://www.billplz-sandbox.com/bills/vcs0gjwv"
            }

            res

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def get_collection(collection_id) do
    url = @endpoint <> "v4/collections/#{collection_id}"

    HTTPoison.get(
      url,
      [{"Content-Type", "application/json"}],
      @auth
    )
  end

  @doc """

  probably only used once...
  """
  def create_collection(title) do
    url = @endpoint <> "/v4/collections"

    case HTTPoison.post(
           url,
           Jason.encode!(%{title: "#{title}"}),
           [{"Content-Type", "application/json"}],
           @auth
         ) do
      {:ok, resp} ->
        case Jason.decode(resp.body) do
          {:ok, res} ->
            IO.inspect(res)

            sample = %{
              "id" => "dpmor8lq",
              "logo" => %{"avatar_url" => nil, "thumb_url" => nil},
              "split_header" => false,
              "split_payments" => [],
              "title" => "HAHO"
            }

            res

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
