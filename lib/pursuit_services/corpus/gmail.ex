defmodule PursuitServices.Corpus.Gmail do
  require Logger

  import Ecto.Query

  alias PursuitServices.Util.REST.Google
  alias PursuitServices.DB
  alias PursuitServices.Shapes.GmailMessage

  @initial_state %{ email_address: "", messages: [] }
  use PursuitServices.Corpus

  def start(email_address) do 
    {_, token} = PursuitServices.Util.Token.Google.get(
      from(u in DB.User, where: u.email == ^email_address, limit: 1) |> DB.one
    )

    {status, pid} = GenServer.start_link(__MODULE__, email_address: email_address)

    case Google.messages_list_all(token["token"]) do
      {:ok, messages} ->
        Enum.each(messages, fn m ->
          Task.start(fn -> 
            case Google.message(token["token"], m["id"], %{"format" => "raw"}) do
              {:ok, blob} ->
                # We want to try and offset the time we make the requests to 
                # lean into the rate limit slower
                :timer.sleep(round(1000 * :rand.uniform))

                GenServer.call(
                  pid, {:put, GmailMessage.new(blob)}, 1000 * 30 * 60
                )
              {:error, %{message: msg}} -> 
                Logger.error("REST Internal Error: #{m["id"]} (#{msg})")
              {:error, other} ->
                Logger.error("Server won't serve message: #{other}")
            end
          end)
        end)

      {:error, e} -> Logger.error("Could not mount corpus: #{e}")
    end

    {status, pid}
  end

  @doc """
    Returns the message in a harness GenServer
  """
  def handle_call(:get, _, %{ messages: [h | t] } = s),
    do: {:reply, Mail.start(h), Map.put(s, :messages, t)}

  def handle_call({:put, %GmailMessage{} = message}, _, %{messages: m} = s),
    do: {:noreply, Map.put(s, :messages, [message | m]) }  

  def handle_call(_, _, s), do: {:reply, :unsupported, s}
end