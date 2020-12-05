defmodule PetstoreTest.Gen.GetPetById do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test
  use ExUnitProperties
  alias Quenya.{RequestHelper, ResponseHelper, TestHelper}
  alias ExJsonSchema.Validator
  @opts apply(Petstore.Gen.Router, :init, [[]])

  property("/pet/{petId}" <> ": should work") do
    check(
      all(
        uri <- TestHelper.stream_gen_uri(path(), params()),
        req_headers <- TestHelper.stream_gen_req_headers(params()),
        req_body <- TestHelper.stream_gen_req_body(content()),
        {code, res_header_schemas, accept, res_body_schema} <- TestHelper.stream_gen_res(res())
      )
    ) do
      conn =
        case(req_body) do
          nil ->
            conn(method(), uri)

          {type, data} ->
            method()
            |> conn(uri, ResponseHelper.encode(type, data))
            |> put_req_header("content-type", type)
            |> put_req_header("accept", accept)
        end

      conn = Enum.reduce(req_headers, conn, fn {k, v}, acc -> put_req_header(acc, k, v) end)
      conn = conn |> RequestHelper.put_security_scheme(security_data())
      conn = apply(router_mod(), :call, [conn, @opts])
      assert(conn.status == code)

      case(ResponseHelper.decode(accept, conn.resp_body)) do
        "" ->
          nil

        v ->
          assert(Validator.valid?(res_body_schema, v))
      end

      Enum.map(res_header_schemas, fn {name, schema} ->
        assert(
          Validator.valid?(
            schema,
            RequestHelper.get_param(conn, name, "resp_header", schema.schema)
          )
        )
      end)
    end
  end

  def method do
    :get
  end

  def path do
    "/pet/{petId}"
  end

  def content do
    %{}
  end

  def params do
    [
      %QuenyaBuilder.Object.Parameter{
        deprecated: false,
        description: "ID of pet to return",
        examples: [],
        explode: false,
        name: "petId",
        position: "path",
        required: true,
        schema: %ExJsonSchema.Schema.Root{
          custom_format_validator: nil,
          location: :root,
          refs: %{},
          schema: %{"format" => "int64", "type" => "integer"}
        },
        style: "simple"
      }
    ]
  end

  def res do
    %{
      "200" => %QuenyaBuilder.Object.Response{
        content: %{
          "application/json" => %QuenyaBuilder.Object.MediaType{
            examples: [],
            schema: %ExJsonSchema.Schema.Root{
              custom_format_validator: nil,
              location: :root,
              refs: %{},
              schema: %{
                "description" => "A pet for sale in the pet store",
                "properties" => %{
                  "category" => %{
                    "description" => "A category for a pet",
                    "properties" => %{
                      "id" => %{"format" => "int64", "type" => "integer"},
                      "name" => %{
                        "pattern" => "^[a-zA-Z0-9]+[a-zA-Z0-9\\.\\-_]*[a-zA-Z0-9]+$",
                        "type" => "string"
                      }
                    },
                    "title" => "Pet category",
                    "type" => "object"
                  },
                  "id" => %{"format" => "int64", "type" => "integer"},
                  "name" => %{"example" => "doggie", "pattern" => "^\\w+$", "type" => "string"},
                  "photoUrls" => %{
                    "items" => %{"format" => "image_uri", "type" => "string"},
                    "type" => "array"
                  },
                  "status" => %{
                    "description" => "pet status in the store",
                    "enum" => ["available", "pending", "sold"],
                    "type" => "string"
                  },
                  "tags" => %{
                    "items" => %{
                      "description" => "A tag for a pet",
                      "properties" => %{
                        "id" => %{"format" => "int64", "type" => "integer"},
                        "name" => %{"type" => "string"}
                      },
                      "title" => "Pet Tag",
                      "type" => "object"
                    },
                    "type" => "array"
                  }
                },
                "required" => ["name", "photoUrls"],
                "title" => "a Pet",
                "type" => "object"
              }
            }
          }
        },
        description: "successful operation",
        headers: %{}
      },
      "400" => %QuenyaBuilder.Object.Response{
        content: %{},
        description: "Invalid ID supplied",
        headers: %{}
      },
      "404" => %QuenyaBuilder.Object.Response{
        content: %{},
        description: "Pet not found",
        headers: %{}
      }
    }
  end

  def router_mod do
    Petstore.Gen.Router
  end

  def security_data do
    {%QuenyaBuilder.Object.SecurityScheme{
       bearerFormat: "JWT",
       description: "",
       name: "",
       position: "",
       scheme: "bearer",
       type: "http"
     }, []}
  end
end