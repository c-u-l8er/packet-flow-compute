defmodule PacketflowChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PacketflowChatWeb.Telemetry,
      PacketflowChat.Repo,
      {DNSCluster, query: Application.get_env(:packetflow_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PacketflowChat.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: PacketflowChat.Finch},
      # Start PacketFlow core systems
      {Registry, keys: :unique, name: PacketFlow.ActorRegistry},
      PacketFlow.ActorSupervisor,
      PacketFlow.CapabilityRegistry,
      PacketFlow.ExecutionEngine,
      PacketFlow.AIPlanner,
      # Start MCP Server
      PacketFlow.MCPServer,
      # Start to serve requests, typically the last entry
      PacketflowChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PacketflowChat.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Load PacketFlow capabilities after everything is started
        Task.start(fn ->
          Process.sleep(1000) # Give systems time to fully start
          PacketFlow.CapabilityLoader.load_all_capabilities()
        end)
        {:ok, pid}

      error -> error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PacketflowChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
