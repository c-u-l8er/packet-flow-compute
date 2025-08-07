#!/usr/bin/env elixir

# File System Example using PacketFlow DSL
# This example demonstrates how to use the DSL macros to build a complete
# file system application with capabilities, contexts, intents, and reactors.

defmodule FileSystemExample do
  use PacketFlow.DSL

  # Define file system capabilities with hierarchical permissions
  defcapability FileSystemCap do
    @implications [
      {FileSystemCap.admin, [FileSystemCap.read, FileSystemCap.write, FileSystemCap.delete, FileSystemCap.execute]},
      {FileSystemCap.delete, [FileSystemCap.read, FileSystemCap.write]},
      {FileSystemCap.write, [FileSystemCap.read]},
      {FileSystemCap.execute, [FileSystemCap.read]}
    ]

    @grants [
      {FileSystemCap.admin, [FileSystemCap.read(:any), FileSystemCap.write(:any), FileSystemCap.delete(:any), FileSystemCap.execute(:any)]},
      {FileSystemCap.delete, [FileSystemCap.read(:any), FileSystemCap.write(:any)]},
      {FileSystemCap.write, [FileSystemCap.read(:any)]},
      {FileSystemCap.execute, [FileSystemCap.read(:any)]}
    ]

    def read(path), do: {:read, path}
    def write(path), do: {:write, path}
    def delete(path), do: {:delete, path}
    def execute(path), do: {:execute, path}
    def admin(), do: {:admin}

    def implies?(cap1, cap2) do
      implications = @implications
      |> Enum.find(fn {cap, _} -> cap == cap1 end)
      |> case do
        {^cap1, implied_caps} -> Enum.any?(implied_caps, &(&1 == cap2))
        _ -> cap1 == cap2
      end
    end

    def grants(capability) do
      grants_map = Map.new(@grants)
      Map.get(grants_map, capability, [])
    end
  end

  # Define user context with capability propagation
  defcontext UserContext do
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
            trace: [target_module | (context.trace || [])]
          }
        :copy ->
          %__MODULE__{
            user_id: context.user_id,
            session_id: context.session_id,
            request_id: generate_request_id(),
            capabilities: context.capabilities,
            trace: context.trace || []
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
            trace: (context1.trace || []) ++ (context2.trace || [])
          }
        :override ->
          context2
      end
    end

    defp compute_capabilities(context) do
      capabilities = case context.user_id do
        "admin" -> MapSet.new([FileSystemCap.admin()])
        "user" -> MapSet.new([FileSystemCap.read(:any), FileSystemCap.write(:any)])
        "guest" -> MapSet.new([FileSystemCap.read(:any)])
        _ -> MapSet.new([FileSystemCap.read(:any)])
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

  # Define file read intent
  defintent FileReadIntent do
    @capabilities [FileSystemCap.read]

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

  # Define file write intent
  defintent FileWriteIntent do
    @capabilities [FileSystemCap.write]

    defstruct [:path, :content, :user_id, :session_id]

    def new(path, content, user_id, session_id) do
      %__MODULE__{
        path: path,
        content: content,
        user_id: user_id,
        session_id: session_id
      }
    end

    def required_capabilities(intent) do
      [FileSystemCap.write(intent.path)]
    end
  end

  # Define file delete intent
  defintent FileDeleteIntent do
    @capabilities [FileSystemCap.delete]

    defstruct [:path, :user_id, :session_id]

    def new(path, user_id, session_id) do
      %__MODULE__{
        path: path,
        user_id: user_id,
        session_id: session_id
      }
    end

    def required_capabilities(intent) do
      [FileSystemCap.delete(intent.path)]
    end
  end

  # Define file system reactor
  defreactor FileSystemReactor do
    @initial_state %{files: %{}, operations: [], users: %{}}

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
        %FileDeleteIntent{} ->
          handle_file_delete(intent, state)
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

    defp handle_file_delete(intent, state) do
      case Map.get(state.files, intent.path) do
        nil ->
          {:error, :file_not_found}
        _content ->
          new_state = state
          |> update_in([:files], &Map.delete(&1, intent.path))
          |> update_in([:operations], &[intent | &1])
          {:ok, new_state, []}
      end
    end
  end

  # Define file system effects
  defmodule FileSystemEffect do
    def read_file(intent) do
      # Simulate file reading effect
      IO.puts("Reading file: #{intent.path}")
      {:ok, "File content for #{intent.path}"}
    end

    def write_file(intent) do
      # Simulate file writing effect
      IO.puts("Writing file: #{intent.path}")
      {:ok, :written}
    end

    def delete_file(intent) do
      # Simulate file deletion effect
      IO.puts("Deleting file: #{intent.path}")
      {:ok, :deleted}
    end
  end

  # Example usage
  def run_example do
    IO.puts("=== File System Example ===")

    # Create contexts for different users
    admin_context = UserContext.new(user_id: "admin", session_id: "session1")
    user_context = UserContext.new(user_id: "user", session_id: "session2")
    guest_context = UserContext.new(user_id: "guest", session_id: "session3")

    IO.puts("Admin capabilities: #{inspect(admin_context.capabilities)}")
    IO.puts("User capabilities: #{inspect(user_context.capabilities)}")
    IO.puts("Guest capabilities: #{inspect(guest_context.capabilities)}")

    # Start the file system reactor
    {:ok, reactor_pid} = FileSystemReactor.start_link()

    # Create intents
    read_intent = FileReadIntent.new("/test.txt", "user", "session2")
    write_intent = FileWriteIntent.new("/test.txt", "Hello, World!", "user", "session2")
    delete_intent = FileDeleteIntent.new("/test.txt", "admin", "session1")

    # Test capability implications
    admin_cap = FileSystemCap.admin()
    read_cap = FileSystemCap.read("/test.txt")
    write_cap = FileSystemCap.write("/test.txt")

    IO.puts("\n=== Capability Tests ===")
    IO.puts("Admin implies read: #{FileSystemCap.implies?(admin_cap, read_cap)}")
    IO.puts("Admin implies write: #{FileSystemCap.implies?(admin_cap, write_cap)}")
    IO.puts("Read implies write: #{FileSystemCap.implies?(read_cap, write_cap)}")

    # Test context propagation
    IO.puts("\n=== Context Propagation ===")
    propagated_context = UserContext.propagate(user_context, FileSystemReactor)
    IO.puts("Original request ID: #{user_context.request_id}")
    IO.puts("Propagated request ID: #{propagated_context.request_id}")
    IO.puts("Trace: #{inspect(propagated_context.trace)}")

    # Test reactor operations
    IO.puts("\n=== Reactor Operations ===")
    
    # Write a file
    {:ok, _effects} = FileSystemReactor.process_intent(write_intent, %{files: %{}, operations: []})
    IO.puts("File written successfully")

    # Read the file
    {:ok, _effects} = FileSystemReactor.process_intent(read_intent, %{files: %{"/test.txt" => "Hello, World!"}, operations: []})
    IO.puts("File read successfully")

    # Delete the file
    {:ok, _effects} = FileSystemReactor.process_intent(delete_intent, %{files: %{"/test.txt" => "Hello, World!"}, operations: []})
    IO.puts("File deleted successfully")

    # Test error cases
    {:error, reason} = FileSystemReactor.process_intent(read_intent, %{files: %{}, operations: []})
    IO.puts("Expected error (file not found): #{reason}")

    IO.puts("\n=== Example completed successfully ===")
  end
end

# Run the example if this file is executed directly
if __ENV__.file == __FILE__ do
  FileSystemExample.run_example()
end 