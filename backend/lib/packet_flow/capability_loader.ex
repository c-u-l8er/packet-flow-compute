defmodule PacketFlow.CapabilityLoader do
  @moduledoc """
  Loads and registers all PacketFlow capabilities in the application.

  This module is responsible for discovering and registering capability modules
  when the application starts.
  """

  require Logger

  @doc """
  Load all capability modules in the application and register them.
  """
  def load_all_capabilities do
    capability_modules = [
      PacketFlow.Capabilities.SimpleChatCapabilities
    ]

    Enum.each(capability_modules, fn module ->
      case PacketFlow.CapabilityRegistry.register_module(module) do
        {:ok, count} ->
          Logger.info("Loaded #{count} capabilities from #{module}")

        {:error, reason} ->
          Logger.error("Failed to load capabilities from #{module}: #{inspect(reason)}")
      end
    end)

    total_capabilities = PacketFlow.CapabilityRegistry.list_all() |> length()
    Logger.info("Total capabilities loaded: #{total_capabilities}")
  end
end
