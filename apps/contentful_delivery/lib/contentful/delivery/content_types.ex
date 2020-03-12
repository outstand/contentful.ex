defmodule Contentful.Delivery.ContentTypes do
  @moduledoc """
  Provides functions around reading content types from spaces
  """

  alias Contentful.{ContentType, Delivery, MetaData, Space}
  alias HTTPoison.Response

  @doc """
  Used to query all the content types for a given space

  ## Examples

      # fetches all content types by a given space id
      iex> {:ok, [%Contentful.ContentType{description: "a description"} | _]} = Contentful.Delivery.ContentTypes.fetch_all("a space_id")
  """
  @spec fetch_all(Space.t() | String.t(), String.t(), String.t() | nil) ::
          {:ok, list(ContentType.t())}
          | {:error, atom(), original_message: String.t()}
  def fetch_all(space, env \\ "master", api_key \\ nil)

  def fetch_all(%Space{meta_data: %{id: id}}, env, api_key) do
    id
    |> build_multiple_request(env, api_key)
    |> Delivery.send_request()
    |> parse_response(&build_content_types/1)
  end

  def fetch_all(space_id, env, api_key) do
    fetch_all(%Space{meta_data: %{id: space_id}}, env, api_key)
  end

  @doc """
  Used to fetch a single ContentType by a space

  ## Examples

      # fetches a content type for a space given
      iex> {:ok, %Contentful.Space{} = space} = Contentful.Delivery.Spaces.fetch_one("a_space_id")
      {:ok, %Contentful.ContentType{description: "a description"}} 
        = space |> Contentful.Delivery.ContentTypes.fetch_one("my_content_type_id")
  """
  @spec fetch_one(
          Space.t() | String.t(),
          String.t(),
          String.t(),
          String.t() | nil
        ) ::
          {:ok, ContentType.t()}
          | {:error, atom(), original_message: String.t()}
          | {:error, :unknown}
  def fetch_one(space, content_type_id, env \\ "master", api_key \\ nil)

  def fetch_one(%Space{meta_data: %{id: id}}, content_type_id, env, api_key) do
    content_type =
      content_type_id
      |> build_single_request(id, env, api_key)
      |> Delivery.send_request()
      |> parse_response(&build_content_type/1)

    case content_type do
      %ContentType{} -> {:ok, content_type}
      _ -> content_type
    end
  end

  def fetch_one(space_id, content_type_id, env, api_key) do
    fetch_one(%Space{meta_data: %{id: space_id}}, content_type_id, env, api_key)
  end

  defp build_multiple_request(space_id, environment, api_key) do
    url =
      [
        Delivery.url(),
        "/spaces/#{space_id}",
        "/environments/#{environment}",
        "/content_types"
      ]
      |> Enum.join()

    {url, api_key |> Delivery.request_headers()}
  end

  defp build_single_request(content_type_id, space_id, environment, api_key) do
    url =
      [
        Delivery.url(),
        "/spaces/#{space_id}",
        "/environments/#{environment}",
        "/content_types",
        "/#{content_type_id}"
      ]
      |> Enum.join()

    {url, api_key |> Delivery.request_headers()}
  end

  defp parse_response(response, callback) do
    with {:ok, %Response{status_code: code, body: body} = resp} <- response do
      case code do
        200 ->
          body |> Contentful.json_library().decode! |> callback.()

        401 ->
          body |> Delivery.build_error(:unauthorized)

        404 ->
          body |> Delivery.build_error(:not_found)

        _ ->
          Delivery.build_error(resp)
      end
    end
  end

  defp build_content_types(%{"items" => items}) do
    {:ok, items |> Enum.map(&build_content_type/1)}
  end

  defp build_content_type(%{
         "name" => name,
         "description" => description,
         "displayField" => display_field,
         "sys" => %{"id" => id, "revision" => rev},
         "fields" => fields
       }) do
    %ContentType{
      name: name,
      description: description,
      display_field: display_field,
      fields: Enum.map(fields, &build_field/1),
      meta_data: %MetaData{id: id, revision: rev}
    }
  end

  defp build_field(%{
         "required" => req,
         "name" => name,
         "localized" => loc,
         "disabled" => disabled,
         "omitted" => omit,
         "type" => type
       }) do
    %ContentType.Field{
      required: req,
      name: name,
      localized: loc,
      disabled: disabled,
      omitted: omit,
      type: type,
      validations: []
    }
  end
end
