defmodule PacketFlow.DSL do
  @moduledoc """
  PacketFlow DSL: Domain-specific language for defining PacketFlow components

  This module provides macros for defining:
  - Intents with capability requirements and effect specifications
  - Contexts with propagation and composition strategies
  - Capabilities with implication hierarchies and grants
  - Reactors with state management and message processing
  """

  defmacro __using__(opts \\ []) do
    quote do
      import PacketFlow.DSL.Intent
      import PacketFlow.DSL.Context
      import PacketFlow.DSL.Capability
      import PacketFlow.DSL.Reactor

      # Enable automatic capability checking
      @capability_check Keyword.get(unquote(opts), :capability_check, true)
    end
  end
end

defmodule PacketFlow.DSL.Intent do
  @moduledoc """
  DSL for defining PacketFlow intents with capability requirements and effects
  """

  @doc """
  Define an intent with capability requirements and effect specifications

  ## Example
  ```elixir
  defintent FileReadIntent do
            @capabilities []
    @effect FileSystemEffect.read_file

    defstruct [:path, :user_id, :session_id]

    def new(path, user_id, session_id) do
      %__MODULE__{
        path: path,
        user_id: user_id,
        session_id: session_id
      }
    end

    def required_capabilities(intent) do
      [FileSystemCap.read(intent.path)]
    end

    def to_reactor_message(intent, opts \\ []) do
      %PacketFlow.Reactor.Message{
        intent: intent,
        capabilities: required_capabilities(intent),
        context: opts[:context] || PacketFlow.Context.empty(),
        metadata: %{type: :file_read, timestamp: System.system_time()},
        timestamp: System.system_time()
      }
    end

    def to_effect(intent, opts \\ []) do
      PacketFlow.Effect.new(
        intent: intent,
        capabilities: required_capabilities(intent),
        context: opts[:context] || PacketFlow.Context.empty(),
        continuation: &FileSystemEffect.read_file/1
      )
    end
  end
  ```
  """
  defmacro defintent(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent

        # Default capability requirements
        @capabilities []

        # Default effect specification
        @effect nil

        unquote(body)

        # Default implementations
        def required_capabilities(intent) do
          @capabilities
        end

        def to_reactor_message(intent, opts \\ []) do
          %PacketFlow.Reactor.Message{
            intent: intent,
            capabilities: required_capabilities(intent),
            context: opts[:context] || PacketFlow.Context.empty(),
            metadata: %{type: :intent, timestamp: System.system_time()},
            timestamp: System.system_time()
          }
        end

        def to_effect(intent, opts \\ []) do
          PacketFlow.Effect.new(
            intent: intent,
            capabilities: required_capabilities(intent),
            context: opts[:context] || PacketFlow.Context.empty(),
            continuation: @effect
          )
        end
      end
    end
  end

  @doc """
  Define a simple intent with minimal boilerplate

  ## Example
  ```elixir
  defsimple_intent FileWriteIntent, [:path, :content, :user_id] do
    @capabilities [FileSystemCap.write]
    @effect FileSystemEffect.write_file
  end
  ```
  """
  defmacro defsimple_intent(name, fields, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent

        # Default capability requirements
        @capabilities []

        # Default effect specification
        @effect nil

        defstruct unquote(fields)

        def new(unquote_splicing(Enum.map(fields, &Macro.var(&1, nil)))) do
          %__MODULE__{unquote_splicing(Enum.zip(fields, Enum.map(fields, &Macro.var(&1, nil))))}
        end

        unquote(body)

        # Default implementations
        def required_capabilities(intent) do
          @capabilities
        end

        def to_reactor_message(intent, opts \\ []) do
          %PacketFlow.Reactor.Message{
            intent: intent,
            capabilities: required_capabilities(intent),
            context: opts[:context] || PacketFlow.Context.empty(),
            metadata: %{type: :intent, timestamp: System.system_time()},
            timestamp: System.system_time()
          }
        end

        def to_effect(intent, opts \\ []) do
          PacketFlow.Effect.new(
            intent: intent,
            capabilities: required_capabilities(intent),
            context: opts[:context] || PacketFlow.Context.empty(),
            continuation: @effect
          )
        end
      end
    end
  end
end

defmodule PacketFlow.DSL.Context do
  @moduledoc """
  DSL for defining PacketFlow contexts with propagation and composition strategies
  """

  @doc """
  Define a context with propagation and composition strategies

  ## Example
  ```elixir
  defcontext RequestContext do
    @propagation_strategy :inherit
    @composition_strategy :merge

    defstruct [:user_id, :session_id, :request_id, :capabilities, :trace]

    def new(attrs \\ []) do
      struct(__MODULE__, attrs)
      |> compute_capabilities()
      |> ensure_request_id()
    end

    def propagate(context, target_module) do
      case @propagation_strategy do
        :inherit ->
          %__MODULE__{
            user_id: context.user_id,
            session_id: context.session_id,
            request_id: generate_request_id(),
            capabilities: context.capabilities,
            trace: [target_module | context.trace]
          }
        :copy ->
          %__MODULE__{
            user_id: context.user_id,
            session_id: context.session_id,
            request_id: generate_request_id(),
            capabilities: context.capabilities,
            trace: context.trace
          }
      end
    end

    def compose(context1, context2, strategy \\ @composition_strategy) do
      case strategy do
        :merge ->
          %__MODULE__{
            user_id: context2.user_id,
            session_id: context2.session_id,
            request_id: generate_request_id(),
            capabilities: MapSet.union(context1.capabilities, context2.capabilities),
            trace: context1.trace ++ context2.trace
          }
        :override ->
          context2
      end
    end

    defp compute_capabilities(context) do
      capabilities = case context.user_id do
        "admin" -> MapSet.new([AdminCap.admin()])
        "user" -> MapSet.new([UserCap.basic()])
        _ -> MapSet.new([GuestCap.read()])
      end
      %{context | capabilities: capabilities}
    end

    defp generate_request_id, do: "req_#{:rand.uniform(1000)}"

    defp ensure_request_id(context) do
      if context.request_id == nil do
        %{context | request_id: generate_request_id()}
      else
        context
      end
    end
  end
  ```
  """
  defmacro defcontext(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Context

        # Default strategies
        @propagation_strategy :inherit
        @composition_strategy :merge

        unquote(body)

        # Default implementations
        def propagate(context, _target_module) do
          context
        end

        def compose(context1, context2, _strategy) do
          context2
        end
      end
    end
  end

  @doc """
  Define a simple context with basic fields

  ## Example
  ```elixir
  defsimple_context UserContext, [:user_id, :session_id, :capabilities] do
    @propagation_strategy :inherit
  end
  ```
  """
  defmacro defsimple_context(name, fields, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Context

        # Default strategies
        @propagation_strategy :inherit
        @composition_strategy :merge

        defstruct unquote(fields)

        unquote(body)

        # Default implementations
        def new(attrs \\ []) do
          struct(__MODULE__, attrs)
        end

        def propagate(context, _target_module) do
          context
        end

        def compose(context1, context2, _strategy) do
          context2
        end
      end
    end
  end
end

defmodule PacketFlow.DSL.Capability do
  @moduledoc """
  DSL for defining PacketFlow capabilities with implication hierarchies and grants
  """

  @doc """
  Define a capability with implication hierarchies and grants

  ## Example
  ```elixir
  defcapability FileSystemCap do
    @implications [
      {FileSystemCap.admin, [FileSystemCap.read, FileSystemCap.write, FileSystemCap.delete]},
      {FileSystemCap.delete, [FileSystemCap.read, FileSystemCap.write]}
    ]

    @grants [
      {FileSystemCap.admin, [FileSystemCap.read(:any), FileSystemCap.write(:any), FileSystemCap.delete(:any)]},
      {FileSystemCap.delete, [FileSystemCap.read(:any), FileSystemCap.write(:any)]}
    ]

    def read(path), do: {:read, path}
    def write(path), do: {:write, path}
    def delete(path), do: {:delete, path}
    def admin(), do: {:admin}

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end

    def compose(caps) when is_list(caps) do
      caps
      |> Enum.reduce(MapSet.new(), fn cap, acc ->
        granted = grants(cap)
        MapSet.union(acc, MapSet.new([cap | granted]))
      end)
    end

    def grants(capability) do
      grants_map = Map.new(@grants)
      Map.get(grants_map, capability, [])
    end
  end
  ```
  """
  defmacro defcapability(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Capability

        # Default implications and grants
        @implications []
        @grants []

        unquote(body)

        # Default implementations
        def implies?(cap1, cap2) do
          implications = @implications
          |> Enum.find(fn {cap, _} -> cap == cap1 end)
          |> case do
            {^cap1, implied_caps} ->
              Enum.any?(implied_caps, fn implied_cap ->
                case {implied_cap, cap2} do
                  {{op, :any}, {op2, _}} when op == op2 -> true
                  {implied_cap, cap2} -> implied_cap == cap2
                end
              end)
            _ -> cap1 == cap2
          end
        end

        def compose(caps) when is_list(caps) do
          caps
          |> Enum.reduce(MapSet.new(), fn cap, acc ->
            granted = grants(cap)
            MapSet.union(acc, MapSet.new([cap | granted]))
          end)
        end

        def grants(capability) do
          []
        end
      end
    end
  end

  @doc """
  Define a simple capability with basic operations

  ## Example
  ```elixir
  defsimple_capability UserCap, [:basic, :admin] do
    @implications [
      {UserCap.admin, [UserCap.basic]}
    ]
  end
  ```
  """
  defmacro defsimple_capability(name, operations, do: body) do
    quote do
      defcapability unquote(name) do
        # Generate the operation functions first
        unquote_splicing(Enum.map(operations, fn op ->
          quote do
            def unquote(op)(), do: {unquote(op)}
          end
        end))

        # Then include the body
        unquote(body)
      end
    end
  end
end

defmodule PacketFlow.DSL.Reactor do
  @moduledoc """
  DSL for defining PacketFlow reactors with state management and message processing
  """

  @doc """
  Define a reactor with state management and message processing

  ## Example
  ```elixir
  defreactor FileSystemReactor do
    @initial_state %{files: %{}, operations: []}
    @capabilities [FileSystemCap.read, FileSystemCap.write, FileSystemCap.delete]

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      state = Keyword.get(opts, :initial_state, @initial_state)
      {:ok, state}
    end

    def handle_call({:process_intent, intent}, _from, state) do
      case process_intent(intent, state) do
        {:ok, new_state, effects} ->
          {:reply, {:ok, effects}, new_state}
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end

    def process_intent(intent, state) do
      case intent do
        %FileReadIntent{} ->
          handle_file_read(intent, state)
        %FileWriteIntent{} ->
          handle_file_write(intent, state)
        _ ->
          {:error, :unsupported_intent}
      end
    end

    defp handle_file_read(intent, state) do
      case Map.get(state.files, intent.path) do
        nil ->
          {:error, :file_not_found}
        content ->
          new_state = update_in(state, [:operations], &[intent | &1])
          {:ok, new_state, []}
      end
    end

    defp handle_file_write(intent, state) do
      new_state = state
      |> update_in([:files], &Map.put(&1, intent.path, intent.content))
      |> update_in([:operations], &[intent | &1])
      {:ok, new_state, []}
    end
  end
  ```
  """
  defmacro defreactor(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Reactor
        use GenServer

        # Default initial state
        @initial_state %{}

        # Default capabilities
        @capabilities []

        unquote(body)

        # Default implementations
        def start_link(opts \\ []) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          state = Keyword.get(opts, :initial_state, @initial_state)
          {:ok, state}
        end

        def handle_call({:process_intent, intent}, from, state) do
          case process_intent(intent, state) do
            {:ok, new_state, effects} ->
              {:reply, {:ok, effects}, new_state}
            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
        end

        def process_intent(intent, state) do
          {:error, :not_implemented}
        end
      end
    end
  end

  @doc """
  Define a simple reactor with basic state management

  ## Example
  ```elixir
  defsimple_reactor CounterReactor, [:count] do
    @capabilities [CounterCap.increment, CounterCap.decrement]

    def process_intent(intent, state) do
      case intent do
        %IncrementIntent{} ->
          new_state = update_in(state, [:count], &(&1 + 1))
          {:ok, new_state, []}
        %DecrementIntent{} ->
          new_state = update_in(state, [:count], &(&1 - 1))
          {:ok, new_state, []}
        _ ->
          {:error, :unsupported_intent}
        end
      end
    end
  end
  ```
  """
  defmacro defsimple_reactor(name, state_fields, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Reactor
        use GenServer

        # Default initial state
        @initial_state %{}

        # Default capabilities
        @capabilities []

        defstruct unquote(state_fields)

        unquote(body)

        # Default implementations
        def start_link(opts \\ []) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          state = struct(__MODULE__, Keyword.get(opts, :initial_state, []))
          {:ok, state}
        end

        def handle_call({:process_intent, intent}, from, state) do
          case process_intent(intent, state) do
            {:ok, new_state, effects} ->
              {:reply, {:ok, effects}, new_state}
            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
        end

        def process_intent(intent, state) do
          {:error, :not_implemented}
        end
      end
    end
  end
end
