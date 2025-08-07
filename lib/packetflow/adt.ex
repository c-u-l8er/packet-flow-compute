defmodule PacketFlow.ADT do
  @moduledoc """
  PacketFlow ADT Substrate: Intent-Context-Capability oriented algebraic data types
  with reactors and effect system integration.

  This substrate provides:
  - Intent modeling through capability-aware sum types
  - Context propagation through enhanced product types
  - Reactor pattern integration with streaming folds
  - Effect system through monadic compositions
  - Capability-based security through type-level constraints
  """

  defmacro __using__(opts \\ []) do
    quote do
      use PacketFlow.DSL, unquote(opts)
      
      # Enable automatic capability checking
      @capability_check Keyword.get(unquote(opts), :capability_check, true)
    end
  end
end

# Supporting behaviour definitions
defmodule PacketFlow.Intent do
  @callback required_capabilities(intent :: any()) :: list(module())
  @callback to_reactor_message(intent :: any(), opts :: keyword()) :: PacketFlow.Reactor.Message.t()
  @callback to_effect(intent :: any(), opts :: keyword()) :: PacketFlow.Effect.t()
end

defmodule PacketFlow.Context do
  @callback new(attrs :: keyword()) :: struct()
  @callback propagate(context :: struct(), target_module :: module()) :: struct()
  @callback compose(context1 :: struct(), context2 :: struct(), strategy :: atom()) :: struct()

  def empty(), do: %{}
end

defmodule PacketFlow.Capability do
  @callback implies?(cap1 :: any(), cap2 :: any()) :: boolean()
  @callback compose(caps :: list(any())) :: MapSet.t()
  @callback grants(capability :: any()) :: list(any())
end

defmodule PacketFlow.Reactor do
  @callback process_intent(intent :: any(), state :: any()) ::
    {:ok, new_state :: any(), effects :: list(any())} |
    {:error, reason :: any()}
end

# Message and Effect structures
defmodule PacketFlow.Reactor.Message do
  defstruct [:intent, :capabilities, :context, :metadata, :timestamp]

  @type t :: %__MODULE__{
    intent: any(),
    capabilities: list(any()),
    context: struct(),
    metadata: map(),
    timestamp: integer()
  }
end

defmodule PacketFlow.Effect do
  defstruct [:intent, :capabilities, :context, :continuation, :status]

  @type t :: %__MODULE__{
    intent: any(),
    capabilities: list(any()),
    context: struct(),
    continuation: function() | nil,
    status: :pending | :running | :completed | :failed
  }

  def new(attrs) do
    struct(__MODULE__, attrs ++ [status: :pending])
  end

  def execute(effect) do
    # Effect execution logic would go here
    effect
  end
end
