defmodule Billplz do
  require Logger

  @endpoint Application.compile_env(:blog_engine, :billplz)[:endpoint] || "https://www.billplz.com/api/v3"
  @api_key Application.compile_env(:blog_engine, :billplz)[:key]

  def create_bill(params) do
    url = "#{@endpoint}/bills"

    # Convert amount to cents if it's a float or decimal string
    amount =
      case params[:amount] do
        amt when is_number(amt) -> round(amt * 100)
        amt when is_binary(amt) -> round(String.to_float(amt) * 100)
        _ -> 0
      end

    body = %{
      "collection_id" => params[:collection_id],
      "email" => params[:email],
      "mobile" => params[:mobile],
      "name" => params[:name],
      "amount" => amount,
      "callback_url" => params[:callback_url],
      "description" => params[:description] || "Payment for Invoices",
      "redirect_url" => params[:redirect_url]
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})

    headers = [
      {"Authorization", "Basic " <> Base.encode64(@api_key <> ":")},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Billplz create_bill failed with status #{status_code}: #{body}")
        {:error, %{status: status_code, body: Jason.decode!(body)}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Billplz create_bill request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_bill(bill_id) do
    url = "#{@endpoint}/bills/#{bill_id}"

    headers = [
      {"Authorization", "Basic " <> Base.encode64(@api_key <> ":")}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Billplz get_bill failed with status #{status_code}: #{body}")
        {:error, %{status: status_code, body: Jason.decode!(body)}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Billplz get_bill request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
