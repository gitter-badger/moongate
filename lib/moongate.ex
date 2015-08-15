defmodule Moongate do
  use Application

  @doc """
    Generic start.
  """
  def start(_type, _args) do
    {:ok, self()}
  end
end

defmodule Mix.Tasks.Moongate.Up do
  use Macros.ExternalResources
  use Macros.Translator

  @doc """
    Initialize the game server.
  """
  def run(_) do
    {:ok, read} = File.read "config/config.json"
    {:ok, config} = JSON.decode(read)

    world = config["world"] || "default"
    Say.greeting
    IO.puts "Starting world #{world}..."
    load_world(world)
    load_scopes(world)
    supervisor = start_supervisor(world)
    spawn_sockets(world)
    Scopes.Start.on_load
    recur

    {:ok, supervisor}
  end

  # Load all modules for game world and set up macros using config files
  defp load_world(world) do
    load_all_in_directory(File.ls("worlds/#{world}/modules"), world)
  end

  # Spawn socket listeners
  defp spawn_sockets(world) do
    {:ok, read} = File.read "worlds/#{world}/ports.json"
    {:ok, ports} = JSON.decode(read)
    ports |> Enum.map(&spawn_socket(&1))
  end

  defp start_supervisor(world) do
    {:ok, read} = File.read "worlds/#{world}/supervisors.json"
    {:ok, world_supervisors} = JSON.decode(read)
    {:ok, supervisor} = Moongate.Supervisor.start_link(world_supervisors)
    GenServer.call(:tree, {:register, supervisor})
    supervisor
  end

  defp spawn_socket({port, params}) do
    case params["protocol"] do
      "TCP" -> spawn_new(:tcp_sockets, String.to_integer(port))
      "UDP" -> spawn_new(:udp_sockets, String.to_integer(port))
      "WebSocket" -> spawn_new(:web_sockets, String.to_integer(port))
      "HTTP" -> spawn_new(:http_hosts, String.to_integer(port))
    end
  end

  # Load all world modules
  defp load_all_in_directory({:ok, files}, world) do
    files = Enum.filter(files, fn(filename) -> Regex.match?(~r/.ex\b/, filename) end)
    files = Enum.map(files, fn(filename) -> "worlds/#{world}/modules/#{filename}" end)
    Enum.map(files, &load_world_module(&1))
  end

  defp load_world_module(filename) do
    Code.eval_file(filename)
    Say.pretty "Compiled #{filename}.", :yellow
  end

  defp load_scopes(world) do
    {:ok, files} = File.ls("worlds/#{world}/scopes")
    Enum.map(files, &load_scope(&1, world))
  end

  defp load_scope(filename, world) do
    Code.eval_file("worlds/#{world}/scopes/#{filename}")
  end

  # Fairly straightforward.
  defp recur do
    recur
  end
end