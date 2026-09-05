defmodule BlogEngine.GoogleIdToken do
  @moduledoc """
  Verifies Google OAuth ID tokens (JWT) using Google's JWKS.
  """

  @jwks_url "https://www.googleapis.com/oauth2/v3/certs"
  @iss MapSet.new(["https://accounts.google.com", "accounts.google.com"])
  @cache_ttl_ms 60 * 60 * 1000

  @doc """
  Verifies `id_token` and returns normalized claims.

  Returns `{:ok, %{sub, email, email_verified, name, picture}}` or `{:error, reason}`.
  """
  def verify(id_token) when is_binary(id_token) and id_token != "" do
    with {:ok, jwk} <- jwk_for_token(id_token),
         {true, %JOSE.JWT{fields: claims}, _} <- JOSE.JWT.verify(jwk, id_token),
         :ok <- validate_claims(claims) do
      {:ok, normalize_claims(claims)}
    else
      {false, _, _} -> {:error, :invalid_signature}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_token}
    end
  end

  def verify(_), do: {:error, :missing_id_token}

  defp jwk_for_token(id_token) do
    try do
      protected = JOSE.JWT.peek_protected(id_token)
      kid = Map.get(protected.fields, "kid") || Map.get(protected.fields, :kid)

      if is_binary(kid) and kid != "" do
        with {:ok, keys} <- fetch_jwks() do
          case Enum.find(keys, fn k -> Map.get(k, "kid") == kid end) do
            nil -> {:error, :unknown_kid}
            key_map -> {:ok, JOSE.JWK.from_map(key_map)}
          end
        end
      else
        {:error, :missing_kid}
      end
    rescue
      _ -> {:error, :malformed_token}
    end
  end

  defp fetch_jwks do
    now = System.system_time(:millisecond)

    case :persistent_term.get({__MODULE__, :jwks}, nil) do
      {keys, expires_at} when is_list(keys) and expires_at > now ->
        {:ok, keys}

      _ ->
        case HTTPoison.get(@jwks_url, [], recv_timeout: 10_000) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"keys" => keys}} when is_list(keys) ->
                :persistent_term.put({__MODULE__, :jwks}, {keys, now + @cache_ttl_ms})
                {:ok, keys}

              _ ->
                {:error, :invalid_jwks}
            end

          _ ->
            {:error, :jwks_fetch_failed}
        end
    end
  end

  defp validate_claims(claims) when is_map(claims) do
    iss = claims["iss"]
    aud = claims["aud"]
    exp = claims["exp"]
    email = claims["email"]
    allowed = allowed_audiences()

    cond do
      not MapSet.member?(@iss, iss) ->
        {:error, :invalid_issuer}

      allowed == [] ->
        {:error, :google_client_ids_not_configured}

      not audience_allowed?(aud, allowed) ->
        {:error, :invalid_audience}

      not is_number(exp) or exp <= System.system_time(:second) ->
        {:error, :token_expired}

      not is_binary(email) or String.trim(email) == "" ->
        {:error, :email_missing}

      true ->
        :ok
    end
  end

  defp validate_claims(_), do: {:error, :invalid_claims}

  defp audience_allowed?(aud, allowed) when is_binary(aud), do: aud in allowed

  defp audience_allowed?(aud, allowed) when is_list(aud),
    do: Enum.any?(aud, &(&1 in allowed))

  defp audience_allowed?(_, _), do: false

  defp allowed_audiences do
    Application.get_env(:blog_engine, :google_client_ids, [])
    |> List.wrap()
    |> Enum.flat_map(fn
      ids when is_binary(ids) ->
        ids
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      id when is_binary(id) ->
        [id]

      _ ->
        []
    end)
    |> Enum.uniq()
  end

  defp normalize_claims(claims) do
    email_verified =
      case claims["email_verified"] do
        true -> true
        "true" -> true
        false -> false
        "false" -> false
        _ -> true
      end

    %{
      "uid" => claims["sub"],
      "sub" => claims["sub"],
      "email" => claims["email"],
      "email_verified" => email_verified,
      "name" => claims["name"] || claims["email"],
      "photo_url" => claims["picture"]
    }
  end
end
