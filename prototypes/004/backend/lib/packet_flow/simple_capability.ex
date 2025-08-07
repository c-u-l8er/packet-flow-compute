defmodule PacketFlow.SimpleCapability do
  @moduledoc """
  Simple capability definition without complex macros.

  This is a temporary solution to get Phase 2 working while we fix the macro system.
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :capabilities, accumulate: true)

      @before_compile PacketFlow.SimpleCapability

      def register_capability(id, metadata, execute_fn) do
        capability = Map.merge(metadata, %{id: id, execute_fn: execute_fn})
        Module.put_attribute(__MODULE__, :capabilities, capability)
      end
    end
  end

  defmacro __before_compile__(env) do
    capabilities = Module.get_attribute(env.module, :capabilities)

    quote do
      def __capabilities__, do: unquote(capabilities)

      def list_capabilities do
        __capabilities__()
        |> Enum.map(fn cap ->
          %{
            id: cap.id,
            intent: cap.intent,
            requires: cap.requires,
            provides: cap.provides,
            effects: cap.effects
          }
        end)
      end
    end
  end
end
