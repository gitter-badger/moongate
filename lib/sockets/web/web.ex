defmodule WebSocket do
  defstruct port: nil
end

defmodule Sockets.Web.Socket do
  use Macros.Packets
  use Macros.Translator

  def start_link(port) do
    link(%WebSocket{port: port}, "socket", "#{port}")
  end

  def handle_cast({:init}, state) do
    Say.pretty("Listening on port #{state.port} (WebSocket)...", :green)

    server = Socket.Web.listen!(state.port) |> accept
    {:noreply, server}
  end

  defp accept(listener) do
    uuid = UUID.uuid4(:hex)
    client = listener |> Socket.Web.accept!
    client |> Socket.Web.accept!

    {:ok, child} = spawn_new(:events, uuid)
    spawn(fn -> handle(client, uuid) end)
    accept(listener)
  end

  defp handle(client, id) do
    case client |> Socket.Web.recv! do
      {:text, message} ->
        incoming = packet_to_list(message)

        if hd(incoming) != :invalid_message do
          tell_async(:events, "#{id}", {:event, tl(incoming), hd(incoming), {client, :web}})
        end

        handle(client, id)
      _ ->
        Say.pretty("Socket with id #{id} disconnected.", :magenta)
        kill_by_id(:events, id)
    end
  end
end