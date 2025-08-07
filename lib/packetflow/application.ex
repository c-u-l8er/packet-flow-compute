defmodule PacketFlow.Application do
  @moduledoc """
  PacketFlow Application: Main application supervisor for the PacketFlow system.
  """
  use Application

  def start(_type, _args) do
    children = [
      # Add any supervisors or workers here as needed
      {PacketFlow.Config, []},
      {PacketFlow.Plugin, []},
      {PacketFlow.Component, []},
      {PacketFlow.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: PacketFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
