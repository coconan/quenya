defmodule QuenyaBuilder.ResponseGenerator do
  @moduledoc """
  Generate fake handler for response
  """
  require DynamicModule
  alias QuenyaBuilder.Util
  alias Quenya.ResponseHelper

  def gen(res, app, name, opts \\ []) do
    mod_name = Util.gen_fake_handler_name(app, name)

    preamble = gen_preamble()
    header = gen_header(res)
    body = gen_body(res)

    contents =
      quote do
        def call(conn, _opts) do
          unquote(header)
          unquote(body)
        end
      end

    DynamicModule.gen(mod_name, preamble, contents, opts)
  end

  def gen_preamble do
    quote do
      require Logger
      import Plug.Conn

      def init(opts) do
        opts
      end
    end
  end

  defp gen_header(data) do
    schemas = Util.get_response_schemas(data, "headers")
    {_code, schemas_with_code} = ResponseHelper.choose_best_response(schemas)

    case Enum.empty?(schemas_with_code) do
      true ->
        quote do
        end

      _ ->
        quote bind_quoted: [schemas_with_code: Macro.escape(schemas_with_code)] do
          conn =
            Enum.reduce(schemas_with_code, conn, fn {name, schema}, acc ->
              v =
                case Quenya.TestHelper.get_one(JsonDataFaker.generate(schema[:schema])) do
                  v when is_binary(v) -> v
                  v when is_integer(v) -> Integer.to_string(v)
                  v -> "#{inspect(v)}"
                end

              Plug.Conn.put_resp_header(acc, name, v)
            end)
        end
    end
  end

  defp gen_body(data) do
    schemas = Util.get_response_schemas(data, "content")

    {code, schema} = ResponseHelper.choose_best_response(schemas)

    case Enum.empty?(schema) do
      true ->
        quote do
          conn
          |> send_resp(unquote(code), "")
        end

      _ ->
        quote bind_quoted: [schemas_with_code: Macro.escape(schema), code: code] do
          accepts = Quenya.RequestHelper.get_accept(conn)

          schema =
            Enum.reduce_while(accepts, nil, fn type, _acc ->
              case(Map.get(schemas_with_code, type)) do
                nil ->
                  {:cont, nil}

                v ->
                  {:halt, Keyword.put(v, :content_type, type)}
              end
            end) || schemas_with_code["application/json"] ||
              raise(
                Plug.BadRequestError,
                "accept content type #{inspect(accepts)} is not supported"
              )

          content_type = Keyword.get(schema, :content_type, "application/json")
          resp = Quenya.TestHelper.get_one(JsonDataFaker.generate(schema[:schema])) || ""

          conn
          |> put_resp_content_type(content_type)
          |> send_resp(code, Quenya.ResponseHelper.encode(content_type, resp))
        end
    end
  end
end
