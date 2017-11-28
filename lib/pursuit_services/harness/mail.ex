defmodule PursuitServices.Harness.Mail do
  require Base
  use GenServer

  alias PursuitServices.Shapes
  alias Mail.Parsers.RFC2822
  alias Mail.Message

  @initial_state %{
    message: %Message{},
    mapped: %{},
    meta: %{}
  }

  @spec start(map) :: {:ok, pid} | {:error, _}
  def start(payload), do: GenServer.start_link(__MODULE__, payload)

  @spec init(map) :: {:ok, map}
  def init(%{} = payload) do 
    state = parse_payload(payload) 
            |> Map.put(:message, RFC2822.parse(state.rfc_blob))
    {:ok, state}
  end

  def handle_call(:features, %{mapped: %{features: f}}), do: {:ok, f}

  @spec parse_payload(Shapes.RawMessage) :: map
  defp parse_payload(%Shapes.RawMessage{} = payload) do
    Map.put(@initial_state, :rfc_blob, Map.get(payload, :raw))
  end

  @spec parse_payload(Shapes.GmailMessage) :: map
  defp parse_payload(%Shapes.GmailMessage{} = payload) do
    meta = Map.take(payload, [:id, :threadId])

    @initial_state |> Map.replace(:meta, meta)
                   |> Map.put(:rfc_blob, Base.url_decode64(payload["raw"]))
  end
end