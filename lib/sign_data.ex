defmodule SignData do
  require Logger

  @spec sign_data(String.t(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def sign_data(data, private_key_path) do
    with {:ok, private_key} <- read_private_key(private_key_path),
         :ok <- check_private_key(private_key),
         signature <- :public_key.sign(data, :sha256, private_key) do
      {:ok, signature}
    else
      {:error, _} = error ->
        error

      _ ->
        {:error, "Failed to sign data"}
    end
  end

  defp read_private_key(path) do
    app_dir = Application.app_dir(:blog_engine)
    path = app_dir <> "/priv/cert/#{path}"

    case File.read(path) do
      {:ok, contents} ->
        IO.inspect(contents)

        case :public_key.pem_decode(contents) |> IO.inspect() do
          [entry] ->
            case :public_key.pem_entry_decode(entry) |> IO.inspect() do
              {:RSAPrivateKey, _} = key ->
                {:ok, key}

              _ ->
                {:error, "Invalid private key type"}
            end

          _ ->
            {:error, "PEM decoding failed"}
        end

      {:error, reason} ->
        {:error, "Failed to read private key: #{reason}"}
    end
  end

  defp check_private_key({:RSAPrivateKey, _} = key) do
    :ok
  end

  defp check_private_key(_) do
    {:error, "Invalid private key"}
  end
end
