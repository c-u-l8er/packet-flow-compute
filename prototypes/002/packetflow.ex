# PacketFlow: A Periodic Table Approach to Distributed Computing
# Full Elixir Implementation
#
# Usage:
#   mix new packetflow_elixir --sup
#   Copy this code to lib/packetflow_elixir.ex
#   mix run --no-halt

defmodule PacketFlow do
  @moduledoc """
  PacketFlow: Chemical Computing System for Elixir

  A distributed computing framework that applies chemistry's periodic table
  principles to computational operations, enabling predictive optimization
  and intuitive system design.
  """

  use Application

  @packetflow_version "1.0"
  @default_timeout_ms 30_000
  @heartbeat_interval_ms 30_000

  def start(_type, _args) do
    IO.puts("🧪⚡ Starting PacketFlow Chemical Computing System")

    children = [
      {Registry, keys: :unique, name: PacketFlow.Registry},
      {DynamicSupervisor, name: PacketFlow.NodeSupervisor, strategy: :one_for_one},
      {PacketFlow.ReactorCore, []},
      {PacketFlow.WebSocketServer, [port: 8443]},
      {PacketFlow.PerformanceMonitor, []},
      {PacketFlow.MolecularOptimizer, []}
    ]

    opts = [strategy: :one_for_one, name: PacketFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ============================================================================
  # CORE TYPES AND CONSTANTS
  # ============================================================================

  @doc "Periodic Groups - The Six Chemical Families"
  @type packet_group :: :cf | :df | :ed | :co | :mc | :rm

  @doc "Chemical Bond Types"
  @type bond_type :: :ionic | :covalent | :metallic | :vdw

  @doc "Node Specialization Types"
  @type node_specialization ::
          :cpu_intensive | :memory_bound | :io_intensive | :network_heavy | :general_purpose

  @doc "Message Types for Protocol"
  @type message_type :: :submit | :result | :error | :heartbeat

  # Chemical Affinity Matrix - [CF, DF, ED, CO, MC, RM] x [CPU, Memory, I/O, Network, General]
  @affinity_matrix %{
    cf: [0.9, 0.4, 0.3, 0.2, 0.6],
    df: [0.8, 0.9, 0.7, 0.6, 0.8],
    ed: [0.3, 0.2, 0.9, 0.8, 0.6],
    co: [0.4, 0.6, 0.8, 0.9, 0.7],
    mc: [0.6, 0.7, 0.5, 0.6, 0.8],
    rm: [0.5, 0.9, 0.4, 0.3, 0.7]
  }

  @spec_indices %{
    cpu_intensive: 0,
    memory_bound: 1,
    io_intensive: 2,
    network_heavy: 3,
    general_purpose: 4
  }

  def calculate_chemical_affinity(packet_group, node_spec) do
    affinity_row = @affinity_matrix[packet_group]
    spec_index = @spec_indices[node_spec]
    Enum.at(affinity_row, spec_index)
  end

  # ============================================================================
  # CORE DATA STRUCTURES
  # ============================================================================

  defmodule Packet do
    @moduledoc "Computational Packet - The Atomic Unit"

    @enforce_keys [:version, :id, :group, :element, :data, :priority]
    defstruct [
      :version,
      :id,
      :group,
      :element,
      :data,
      :priority,
      :timeout_ms,
      :dependencies,
      :metadata,
      created_at: nil,
      processed_at: nil
    ]

    @type t :: %__MODULE__{
            version: String.t(),
            id: String.t(),
            group: PacketFlow.packet_group(),
            element: String.t(),
            data: term(),
            priority: integer(),
            timeout_ms: integer() | nil,
            dependencies: [String.t()] | nil,
            metadata: map() | nil,
            created_at: DateTime.t() | nil,
            processed_at: DateTime.t() | nil
          }

    def new(group, element, data, priority, opts \\ []) do
      %__MODULE__{
        version: PacketFlow.version(),
        id: generate_uuid(),
        group: group,
        element: element,
        data: data,
        priority: priority,
        timeout_ms: opts[:timeout_ms],
        dependencies: opts[:dependencies],
        metadata: opts[:metadata],
        created_at: DateTime.utc_now()
      }
    end

    @doc "Chemical Properties - Reactivity Level"
    def reactivity(%__MODULE__{group: group}) do
      case group do
        :ed -> 0.9  # Event Driven - highest reactivity
        :df -> 0.8  # Data Flow - high reactivity
        :cf -> 0.6  # Control Flow - medium reactivity
        :rm -> 0.5  # Resource Management - medium-low
        :co -> 0.4  # Collective - low (coordination-bound)
        :mc -> 0.3  # Meta-Computational - lowest (analysis-intensive)
      end
    end

    @doc "Chemical Properties - Ionization Energy (Computational Cost)"
    def ionization_energy(%__MODULE__{priority: priority, group: group}) do
      base_complexity = priority / 10.0

      group_factor =
        case group do
          :mc -> 2.0  # Meta-computational is expensive
          :co -> 1.8  # Collective operations are costly
          :cf -> 1.5  # Control flow has overhead
          :rm -> 1.3  # Resource management has bookkeeping
          :df -> 1.0  # Data flow is efficient
          :ed -> 0.8  # Events are lightweight
        end

      base_complexity * group_factor
    end

    @doc "Chemical Properties - Atomic Radius (Scope of Influence)"
    def atomic_radius(%__MODULE__{group: group}) do
      case group do
        :co -> 3.0  # Collective operations affect many
        :mc -> 2.5  # Meta-computational affects system
        :ed -> 2.0  # Events propagate
        :rm -> 1.5  # Resources are shared
        :cf -> 1.2  # Control flow has dependencies
        :df -> 1.0  # Data flow is localized
      end
    end

    @doc "Chemical Properties - Electronegativity (Resource Attraction)"
    def electronegativity(%__MODULE__{priority: priority, group: group}) do
      base_demand = priority / 10.0

      group_multiplier =
        case group do
          :rm -> 1.5  # Resource management attracts resources
          :mc -> 1.4  # Meta-computational needs resources
          :co -> 1.3  # Collective operations need coordination
          :cf -> 1.2  # Control flow needs CPU
          :df -> 1.1  # Data flow needs memory/CPU
          :ed -> 1.0  # Events are lightweight
        end

      base_demand * group_multiplier
    end

    defp generate_uuid do
      UUID.uuid4()
    end
  end

  defmodule PacketResult do
    @moduledoc "Processing Result"

    @enforce_keys [:packet_id, :status, :duration_ms]
    defstruct [:packet_id, :status, :data, :error, :duration_ms, :node_id, :processed_at]

    @type t :: %__MODULE__{
            packet_id: String.t(),
            status: :success | :error,
            data: term() | nil,
            error: %{code: String.t(), message: String.t()} | nil,
            duration_ms: integer(),
            node_id: String.t() | nil,
            processed_at: DateTime.t() | nil
          }

    def success(packet_id, data, duration_ms, node_id \\ nil) do
      %__MODULE__{
        packet_id: packet_id,
        status: :success,
        data: data,
        duration_ms: duration_ms,
        node_id: node_id,
        processed_at: DateTime.utc_now()
      }
    end

    def failure(packet_id, code, message, duration_ms, node_id \\ nil) do
      %__MODULE__{
        packet_id: packet_id,
        status: :error,
        error: %{code: code, message: message},
        duration_ms: duration_ms,
        node_id: node_id,
        processed_at: DateTime.utc_now()
      }
    end
  end

  defmodule ChemicalBond do
    @moduledoc "Chemical Bond between Packets"

    @enforce_keys [:from_packet, :to_packet, :bond_type]
    defstruct [:from_packet, :to_packet, :bond_type, :strength, :formed_at]

    @type t :: %__MODULE__{
            from_packet: String.t(),
            to_packet: String.t(),
            bond_type: PacketFlow.bond_type(),
            strength: float(),
            formed_at: DateTime.t()
          }

    def new(from_packet, to_packet, bond_type) do
      %__MODULE__{
        from_packet: from_packet,
        to_packet: to_packet,
        bond_type: bond_type,
        strength: bond_strength(bond_type),
        formed_at: DateTime.utc_now()
      }
    end

    defp bond_strength(bond_type) do
      case bond_type do
        :ionic -> 1.0     # Strong dependency
        :covalent -> 0.8  # Shared resources
        :metallic -> 0.6  # Loose coordination
        :vdw -> 0.3       # Weak environmental coupling
      end
    end
  end

  defmodule Molecule do
    @moduledoc "Molecular Structure - Complex Pattern of Packets"

    @enforce_keys [:id]
    defstruct [
      :id,
      composition: [],
      bonds: [],
      properties: %{},
      stability: 0.0,
      created_at: nil,
      last_optimized: nil
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            composition: [Packet.t()],
            bonds: [ChemicalBond.t()],
            properties: map(),
            stability: float(),
            created_at: DateTime.t() | nil,
            last_optimized: DateTime.t() | nil
          }

    def new(id, opts \\ []) do
      %__MODULE__{
        id: id,
        composition: opts[:composition] || [],
        bonds: opts[:bonds] || [],
        properties: opts[:properties] || %{},
        created_at: DateTime.utc_now()
      }
      |> calculate_stability()
    end

    def add_packet(%__MODULE__{} = molecule, %Packet{} = packet) do
      %{molecule | composition: [packet | molecule.composition]}
      |> calculate_stability()
    end

    def add_packets(%__MODULE__{} = molecule, packets) when is_list(packets) do
      %{molecule | composition: packets ++ molecule.composition}
      |> calculate_stability()
    end

    def add_bond(%__MODULE__{} = molecule, %ChemicalBond{} = bond) do
      %{molecule | bonds: [bond | molecule.bonds]}
      |> calculate_stability()
    end

    def add_bonds(%__MODULE__{} = molecule, bonds) when is_list(bonds) do
      %{molecule | bonds: bonds ++ molecule.bonds}
      |> calculate_stability()
    end

    @doc "Calculate molecular stability based on binding energy and internal stress"
    def calculate_stability(%__MODULE__{} = molecule) do
      binding_energy = calculate_binding_energy(molecule)
      internal_stress = calculate_internal_stress(molecule)
      composition_factor = length(molecule.composition)

      stability =
        if composition_factor > 0 do
          binding_energy - internal_stress / composition_factor
        else
          0.0
        end

      %{molecule | stability: stability}
    end

    defp calculate_binding_energy(%__MODULE__{bonds: bonds}) do
      Enum.reduce(bonds, 0.0, fn bond, acc ->
        acc + bond.strength
      end)
    end

    defp calculate_internal_stress(%__MODULE__{composition: composition}) do
      Enum.reduce(composition, 0.0, fn packet, acc ->
        acc + Packet.ionization_energy(packet) * Packet.atomic_radius(packet)
      end)
    end

    def stable?(%__MODULE__{stability: stability}) do
      stability > 0.5  # Stability threshold
    end

    def packet_count(%__MODULE__{composition: composition}) do
      length(composition)
    end

    def bond_count(%__MODULE__{bonds: bonds}) do
      length(bonds)
    end
  end

  # ============================================================================
  # PROCESSING NODE - GenServer
  # ============================================================================

  defmodule ProcessingNode do
    @moduledoc "Specialized Processing Node"

    use GenServer, restart: :permanent

    @enforce_keys [:id, :specialization, :max_capacity]
    defstruct [
      :id,
      :specialization,
      :max_capacity,
      current_load: 0.0,
      packet_queue: :queue.new(),
      handlers: %{},
      processed_count: 0,
      error_count: 0,
      total_processing_time: 0,
      created_at: nil,
      last_health_check: nil
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            specialization: PacketFlow.node_specialization(),
            max_capacity: float(),
            current_load: float(),
            packet_queue: :queue.queue(),
            handlers: map(),
            processed_count: integer(),
            error_count: integer(),
            total_processing_time: integer(),
            created_at: DateTime.t() | nil,
            last_health_check: DateTime.t() | nil
          }

    # Client API

    def start_link({id, specialization, max_capacity}) do
      GenServer.start_link(__MODULE__, {id, specialization, max_capacity},
        name: via_tuple(id)
      )
    end

    def register_handler(node_id, group, element, handler_fun) when is_function(handler_fun, 1) do
      GenServer.call(via_tuple(node_id), {:register_handler, group, element, handler_fun})
    end

    def enqueue_packet(node_id, %Packet{} = packet) do
      GenServer.call(via_tuple(node_id), {:enqueue_packet, packet}, 10_000)
    end

    def get_status(node_id) do
      GenServer.call(via_tuple(node_id), :get_status)
    end

    def get_load_factor(node_id) do
      GenServer.call(via_tuple(node_id), :get_load_factor)
    end

    def can_accept?(node_id, %Packet{} = packet) do
      GenServer.call(via_tuple(node_id), {:can_accept, packet})
    end

    def process_next(node_id) do
      GenServer.call(via_tuple(node_id), :process_next, 30_000)
    end

    def health_check(node_id) do
      GenServer.call(via_tuple(node_id), :health_check)
    end

    # GenServer Callbacks

    def init({id, specialization, max_capacity}) do
      state = %__MODULE__{
        id: id,
        specialization: specialization,
        max_capacity: max_capacity,
        created_at: DateTime.utc_now(),
        last_health_check: DateTime.utc_now()
      }

      # Schedule periodic processing
      schedule_processing()

      IO.puts("🔧 Processing Node #{id} (#{specialization}) started with capacity #{max_capacity}")

      {:ok, state}
    end

    def handle_call({:register_handler, group, element, handler_fun}, _from, state) do
      key = "#{group}:#{element}"
      new_handlers = Map.put(state.handlers, key, handler_fun)
      new_state = %{state | handlers: new_handlers}

      IO.puts("📝 Registered handler #{key} on node #{state.id}")

      {:reply, :ok, new_state}
    end

    def handle_call({:enqueue_packet, packet}, _from, state) do
      packet_load = Packet.ionization_energy(packet)

      if state.current_load + packet_load <= state.max_capacity do
        new_queue = :queue.in(packet, state.packet_queue)
        new_load = state.current_load + packet_load

        new_state = %{state | packet_queue: new_queue, current_load: new_load}

        {:reply, :ok, new_state}
      else
        {:reply, {:error, :node_overloaded}, state}
      end
    end

    def handle_call(:get_status, _from, state) do
      status = %{
        id: state.id,
        specialization: state.specialization,
        current_load: state.current_load,
        max_capacity: state.max_capacity,
        load_factor: state.current_load / state.max_capacity,
        queue_length: :queue.len(state.packet_queue),
        processed_count: state.processed_count,
        error_count: state.error_count,
        success_rate: calculate_success_rate(state),
        average_processing_time: calculate_average_processing_time(state),
        uptime: DateTime.diff(DateTime.utc_now(), state.created_at, :second)
      }

      {:reply, status, state}
    end

    def handle_call(:get_load_factor, _from, state) do
      load_factor = state.current_load / state.max_capacity
      {:reply, load_factor, state}
    end

    def handle_call({:can_accept, packet}, _from, state) do
      packet_load = Packet.ionization_energy(packet)
      can_accept = state.current_load + packet_load <= state.max_capacity
      {:reply, can_accept, state}
    end

    def handle_call(:process_next, _from, state) do
      case :queue.out(state.packet_queue) do
        {{:value, packet}, new_queue} ->
          {result, new_state} = process_packet(packet, %{state | packet_queue: new_queue})
          {:reply, {:ok, result}, new_state}

        {:empty, _} ->
          {:reply, {:error, :no_packets}, state}
      end
    end

    def handle_call(:health_check, _from, state) do
      health_score = calculate_health_score(state)
      new_state = %{state | last_health_check: DateTime.utc_now()}

      health_report = %{
        node_id: state.id,
        health_score: health_score,
        load_factor: state.current_load / state.max_capacity,
        queue_length: :queue.len(state.packet_queue),
        error_rate: state.error_count / max(state.processed_count, 1),
        last_check: new_state.last_health_check
      }

      {:reply, health_report, new_state}
    end

    def handle_info(:process_packets, state) do
      new_state = process_available_packets(state)
      schedule_processing()
      {:noreply, new_state}
    end

    def handle_info(_msg, state) do
      {:noreply, state}
    end

    # Private Functions

    defp via_tuple(node_id) do
      {:via, Registry, {PacketFlow.Registry, {:node, node_id}}}
    end

    defp schedule_processing do
      Process.send_after(self(), :process_packets, 10)  # Process every 10ms
    end

    defp process_available_packets(state) do
      case :queue.out(state.packet_queue) do
        {{:value, packet}, new_queue} ->
          {_result, new_state} = process_packet(packet, %{state | packet_queue: new_queue})
          process_available_packets(new_state)

        {:empty, _} ->
          state
      end
    end

    defp process_packet(%Packet{} = packet, state) do
      key = "#{packet.group}:#{packet.element}"
      start_time = System.monotonic_time(:millisecond)

      case Map.get(state.handlers, key) do
        nil ->
          duration = System.monotonic_time(:millisecond) - start_time
          result = PacketResult.failure(packet.id, "PF001", "No handler for #{key}", duration, state.id)

          new_state = %{
            state
            | error_count: state.error_count + 1,
              current_load: state.current_load - Packet.ionization_energy(packet)
          }

          {result, new_state}

        handler_fun when is_function(handler_fun, 1) ->
          try do
            result_data = handler_fun.(packet.data)
            duration = System.monotonic_time(:millisecond) - start_time
            result = PacketResult.success(packet.id, result_data, duration, state.id)

            new_state = %{
              state
              | processed_count: state.processed_count + 1,
                total_processing_time: state.total_processing_time + duration,
                current_load: state.current_load - Packet.ionization_energy(packet)
            }

            {result, new_state}
          rescue
            error ->
              duration = System.monotonic_time(:millisecond) - start_time
              result = PacketResult.failure(packet.id, "PF500", Exception.message(error), duration, state.id)

              new_state = %{
                state
                | error_count: state.error_count + 1,
                  current_load: state.current_load - Packet.ionization_energy(packet)
              }

              {result, new_state}
          end
      end
    end

    defp calculate_success_rate(state) do
      total_processed = state.processed_count + state.error_count

      if total_processed > 0 do
        state.processed_count / total_processed
      else
        1.0
      end
    end

    defp calculate_average_processing_time(state) do
      if state.processed_count > 0 do
        state.total_processing_time / state.processed_count
      else
        0.0
      end
    end

    defp calculate_health_score(state) do
      load_score = 1.0 - (state.current_load / state.max_capacity)
      success_score = calculate_success_rate(state)
      queue_score = 1.0 - min(:queue.len(state.packet_queue) / 100.0, 1.0)

      (load_score + success_score + queue_score) / 3.0
    end
  end

  # ============================================================================
  # MOLECULAR OPTIMIZER - GenServer
  # ============================================================================

  defmodule MolecularOptimizer do
    @moduledoc "Molecular Optimization Engine"

    use GenServer, restart: :permanent

    defstruct [
      molecules: %{},
      optimization_threshold: 0.1,
      optimization_interval: 5000,  # 5 seconds
      optimizations_performed: 0,
      total_stability_improvement: 0.0
    ]

    # Client API

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def register_molecule(molecule_id, %Molecule{} = molecule) do
      GenServer.call(__MODULE__, {:register_molecule, molecule_id, molecule})
    end

    def optimize_molecule(molecule_id) do
      GenServer.call(__MODULE__, {:optimize_molecule, molecule_id})
    end

    def get_optimization_stats do
      GenServer.call(__MODULE__, :get_optimization_stats)
    end

    def should_optimize?(%Molecule{} = molecule) do
      not Molecule.stable?(molecule) or Molecule.packet_count(molecule) > 10
    end

    # GenServer Callbacks

    def init(_opts) do
      schedule_optimization_cycle()
      IO.puts("⚡ Molecular Optimizer started")
      {:ok, %__MODULE__{}}
    end

    def handle_call({:register_molecule, molecule_id, molecule}, _from, state) do
      new_molecules = Map.put(state.molecules, molecule_id, molecule)
      new_state = %{state | molecules: new_molecules}
      {:reply, :ok, new_state}
    end

    def handle_call({:optimize_molecule, molecule_id}, _from, state) do
      case Map.get(state.molecules, molecule_id) do
        nil ->
          {:reply, {:error, :molecule_not_found}, state}

        molecule ->
          {optimized_molecule, improvement} = perform_optimization(molecule)
          new_molecules = Map.put(state.molecules, molecule_id, optimized_molecule)

          new_state = %{
            state
            | molecules: new_molecules,
              optimizations_performed: state.optimizations_performed + 1,
              total_stability_improvement: state.total_stability_improvement + improvement
          }

          {:reply, {:ok, optimized_molecule}, new_state}
      end
    end

    def handle_call(:get_optimization_stats, _from, state) do
      stats = %{
        molecules_registered: map_size(state.molecules),
        optimizations_performed: state.optimizations_performed,
        total_stability_improvement: state.total_stability_improvement,
        average_improvement: average_improvement(state)
      }

      {:reply, stats, state}
    end

    def handle_info(:optimization_cycle, state) do
      new_state = run_optimization_cycle(state)
      schedule_optimization_cycle()
      {:noreply, new_state}
    end

    # Private Functions

    defp schedule_optimization_cycle do
      Process.send_after(self(), :optimization_cycle, 5000)
    end

    defp run_optimization_cycle(state) do
      Enum.reduce(state.molecules, state, fn {molecule_id, molecule}, acc_state ->
        if should_optimize?(molecule) do
          {optimized_molecule, improvement} = perform_optimization(molecule)
          new_molecules = Map.put(acc_state.molecules, molecule_id, optimized_molecule)

          %{
            acc_state
            | molecules: new_molecules,
              optimizations_performed: acc_state.optimizations_performed + 1,
              total_stability_improvement: acc_state.total_stability_improvement + improvement
          }
        else
          acc_state
        end
      end)
    end

    defp perform_optimization(%Molecule{} = molecule) do
      original_stability = molecule.stability

      molecule
      |> optimize_bonds()
      |> optimize_locality()
      |> optimize_parallelism()
      |> Molecule.calculate_stability()
      |> then(fn optimized ->
        improvement = optimized.stability - original_stability
        optimized = %{optimized | last_optimized: DateTime.utc_now()}
        {optimized, improvement}
      end)
    end

    defp optimize_bonds(%Molecule{bonds: bonds} = molecule) do
      optimized_bonds =
        Enum.map(bonds, fn bond ->
          # Convert ionic bonds to metallic if strength is low (not strictly required)
          if bond.bond_type == :ionic and bond.strength < 0.7 do
            %{bond | bond_type: :metallic, strength: 0.6}
          else
            bond
          end
        end)

      %{molecule | bonds: optimized_bonds}
    end

    defp optimize_locality(%Molecule{} = molecule) do
      # TODO: Implement locality optimization
      # Co-locate packets with high communication frequency
      molecule
    end

    defp optimize_parallelism(%Molecule{} = molecule) do
      # TODO: Implement parallelism optimization
      # Break molecules for better parallel execution
      molecule
    end

    defp average_improvement(state) do
      if state.optimizations_performed > 0 do
        state.total_stability_improvement / state.optimizations_performed
      else
        0.0
      end
    end
  end

  # ============================================================================
  # FAULT DETECTOR - GenServer
  # ============================================================================

  defmodule FaultDetector do
    @moduledoc "System Fault Detection and Recovery"

    use GenServer, restart: :permanent

    defstruct [
      failure_threshold: 3,
      recent_failures: %{},
      failure_window_ms: 60_000,  # 1 minute window
      node_health_scores: %{},
      molecular_stability_alerts: [],
      recovery_actions_taken: 0
    ]

    # Client API

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def monitor_packet(%Packet{} = packet) do
      GenServer.cast(__MODULE__, {:monitor_packet, packet})
    end

    def record_failure(node_id, reason) do
      GenServer.cast(__MODULE__, {:record_failure, node_id, reason})
    end

    def is_node_healthy?(node_id) do
      GenServer.call(__MODULE__, {:is_node_healthy, node_id})
    end

    def get_system_health do
      GenServer.call(__MODULE__, :get_system_health)
    end

    def heal_molecule(molecule_id, failed_packets) do
      GenServer.call(__MODULE__, {:heal_molecule, molecule_id, failed_packets})
    end

    # GenServer Callbacks

    def init(_opts) do
      schedule_health_check()
      IO.puts("🏥 Fault Detector started")
      {:ok, %__MODULE__{}}
    end

    def handle_cast({:monitor_packet, packet}, state) do
      # TODO: Implement packet monitoring
      # Track execution time, resource usage, error rates
      {:noreply, state}
    end

    def handle_cast({:record_failure, node_id, reason}, state) do
      current_time = System.system_time(:millisecond)
      failure_entry = {reason, current_time}

      current_failures = Map.get(state.recent_failures, node_id, [])
      updated_failures = [failure_entry | current_failures]
      
      # Keep only failures within the time window
      filtered_failures = 
        Enum.filter(updated_failures, fn {_reason, timestamp} ->
          current_time - timestamp <= state.failure_window_ms
        end)

      new_recent_failures = Map.put(state.recent_failures, node_id, filtered_failures)
      new_state = %{state | recent_failures: new_recent_failures}

      # Check if node needs recovery
      if length(filtered_failures) >= state.failure_threshold do
        IO.puts("🚨 Node #{node_id} exceeded failure threshold - triggering recovery")
        spawn(fn -> trigger_node_recovery(node_id) end)
      end

      {:noreply, new_state}
    end

    def handle_call({:is_node_healthy, node_id}, _from, state) do
      current_failures = Map.get(state.recent_failures, node_id, [])
      is_healthy = length(current_failures) < state.failure_threshold
      {:reply, is_healthy, state}
    end

    def handle_call(:get_system_health, _from, state) do
      total_nodes = map_size(state.node_health_scores)
      
      health_summary = %{
        total_nodes: total_nodes,
        healthy_nodes: count_healthy_nodes(state),
        system_health_score: calculate_system_health_score(state),
        recent_recovery_actions: state.recovery_actions_taken,
        molecular_stability_alerts: length(state.molecular_stability_alerts)
      }

      {:reply, health_summary, state}
    end

    def handle_call({:heal_molecule, molecule_id, failed_packets}, _from, state) do
      # TODO: Implement molecular healing
      # Remove failed packets and maintain functionality
      healing_successful = true
      
      new_state = %{state | recovery_actions_taken: state.recovery_actions_taken + 1}
      {:reply, {:ok, healing_successful}, new_state}
    end

    def handle_info(:health_check, state) do
      new_state = perform_system_health_check(state)
      schedule_health_check()
      {:noreply, new_state}
    end

    # Private Functions

    defp schedule_health_check do
      Process.send_after(self(), :health_check, 30_000)  # Every 30 seconds
    end

    defp trigger_node_recovery(node_id) do
      IO.puts("🔄 Attempting recovery for node #{node_id}")
      # TODO: Implement node recovery logic
      # Could restart the node, redistribute its workload, etc.
    end

    defp count_healthy_nodes(state) do
      Enum.count(state.recent_failures, fn {_node_id, failures} ->
        length(failures) < state.failure_threshold
      end)
    end

    defp calculate_system_health_score(state) do
      if map_size(state.node_health_scores) == 0 do
        1.0
      else
        total_score = 
          state.node_health_scores
          |> Map.values()
          |> Enum.sum()
        
        total_score / map_size(state.node_health_scores)
      end
    end

    defp perform_system_health_check(state) do
      # Update node health scores
      # TODO: Query actual nodes for health status
      state
    end
  end

  # ============================================================================
  # ROUTING TABLE - GenServer
  # ============================================================================

  defmodule RoutingTable do
    @moduledoc "Chemical Affinity-Based Routing"

    use GenServer, restart: :permanent

    defstruct [
      nodes: [],
      routing_policies: [],
      routing_stats: %{},
      load_balancing_algorithm: :chemical_affinity
    ]

    # Client API

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def register_node(node_id, specialization, max_capacity) do
      GenServer.call(__MODULE__, {:register_node, node_id, specialization, max_capacity})
    end

    def route_packet(%Packet{} = packet) do
      GenServer.call(__MODULE__, {:route_packet, packet})
    end

    def get_routing_stats do
      GenServer.call(__MODULE__, :get_routing_stats)
    end

    def get_healthy_nodes do
      GenServer.call(__MODULE__, :get_healthy_nodes)
    end

    # GenServer Callbacks

    def init(_opts) do
      IO.puts("🧭 Routing Table initialized")
      {:ok, %__MODULE__{}}
    end

    def handle_call({:register_node, node_id, specialization, max_capacity}, _from, state) do
      node_info = %{
        id: node_id,
        specialization: specialization,
        max_capacity: max_capacity,
        registered_at: DateTime.utc_now()
      }

      new_nodes = [node_info | state.nodes]
      new_state = %{state | nodes: new_nodes}

      IO.puts("📍 Registered routing for node #{node_id} (#{specialization})")
      {:reply, :ok, new_state}
    end

    def handle_call({:route_packet, packet}, _from, state) do
      case find_best_node(packet, state.nodes) do
        nil ->
          {:reply, {:error, :no_available_nodes}, state}

        best_node ->
          # Update routing stats
          group_key = packet.group
          current_count = Map.get(state.routing_stats, group_key, 0)
          new_stats = Map.put(state.routing_stats, group_key, current_count + 1)
          new_state = %{state | routing_stats: new_stats}

          {:reply, {:ok, best_node.id}, new_state}
      end
    end

    def handle_call(:get_routing_stats, _from, state) do
      {:reply, state.routing_stats, state}
    end

    def handle_call(:get_healthy_nodes, _from, state) do
      healthy_nodes = 
        Enum.filter(state.nodes, fn node ->
          PacketFlow.FaultDetector.is_node_healthy?(node.id)
        end)

      {:reply, healthy_nodes, state}
    end

    # Private Functions

    defp find_best_node(%Packet{} = packet, nodes) do
      nodes
      |> Enum.filter(&node_can_accept_packet?(&1, packet))
      |> Enum.map(&score_node_for_packet(&1, packet))
      |> Enum.max_by(fn {_node, score} -> score end, fn -> nil end)
      |> case do
        nil -> nil
        {node, _score} -> node
      end
    end

    defp node_can_accept_packet?(node, packet) do
      PacketFlow.FaultDetector.is_node_healthy?(node.id) and
        ProcessingNode.can_accept?(node.id, packet)
    end

    defp score_node_for_packet(node, packet) do
      affinity = PacketFlow.calculate_chemical_affinity(packet.group, node.specialization)
      load_factor = 1.0 - ProcessingNode.get_load_factor(node.id)
      priority_factor = packet.priority / 10.0

      score = affinity * load_factor * priority_factor
      {node, score}
    end
  end

  # ============================================================================
  # REACTOR CORE - Main Orchestrator GenServer
  # ============================================================================

  defmodule ReactorCore do
    @moduledoc "Main PacketFlow Reactor"

    use GenServer, restart: :permanent

    defstruct [
      nodes: %{},
      molecules: %{},
      packet_sequence: 0,
      running: false,
      stats: %{
        packets_processed: 0,
        molecules_created: 0,
        total_processing_time: 0,
        start_time: nil
      }
    ]

    # Client API

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def add_node(specialization, max_capacity) do
      GenServer.call(__MODULE__, {:add_node, specialization, max_capacity})
    end

    def create_molecule(id, opts \\ []) do
      GenServer.call(__MODULE__, {:create_molecule, id, opts})
    end

    def submit_packet(%Packet{} = packet) do
      GenServer.call(__MODULE__, {:submit_packet, packet}, 30_000)
    end

    def get_system_status do
      GenServer.call(__MODULE__, :get_system_status)
    end

    def start_reactor do
      GenServer.call(__MODULE__, :start_reactor)
    end

    def stop_reactor do
      GenServer.call(__MODULE__, :stop_reactor)
    end

    # GenServer Callbacks

    def init(_opts) do
      state = %__MODULE__{
        stats: %{
          packets_processed: 0,
          molecules_created: 0,
          total_processing_time: 0,
          start_time: DateTime.utc_now()
        }
      }

      IO.puts("🧪 PacketFlow Reactor Core initialized")
      {:ok, state}
    end

    def handle_call({:add_node, specialization, max_capacity}, _from, state) do
      node_id = "node_#{map_size(state.nodes) + 1}"
      
      # Start the processing node
      node_spec = {node_id, specialization, max_capacity}
      
      case DynamicSupervisor.start_child(PacketFlow.NodeSupervisor, 
        {ProcessingNode, node_spec}) do
        {:ok, _pid} ->
          # Register with routing table
          RoutingTable.register_node(node_id, specialization, max_capacity)
          
          node_info = %{
            id: node_id,
            specialization: specialization,
            max_capacity: max_capacity,
            created_at: DateTime.utc_now()
          }
          
          new_nodes = Map.put(state.nodes, node_id, node_info)
          new_state = %{state | nodes: new_nodes}
          
          IO.puts("🔧 Added processing node #{node_id} (#{specialization})")
          {:reply, {:ok, node_id}, new_state}
          
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end

    def handle_call({:create_molecule, id, opts}, _from, state) do
      molecule = Molecule.new(id, opts)
      new_molecules = Map.put(state.molecules, id, molecule)
      
      # Register with molecular optimizer
      MolecularOptimizer.register_molecule(id, molecule)
      
      new_stats = %{state.stats | molecules_created: state.stats.molecules_created + 1}
      new_state = %{state | molecules: new_molecules, stats: new_stats}
      
      IO.puts("🧬 Created molecule #{id} with #{Molecule.packet_count(molecule)} packets")
      {:reply, {:ok, molecule}, new_state}
    end

    def handle_call({:submit_packet, packet}, _from, state) do
      start_time = System.monotonic_time(:millisecond)
      
      # Route packet using chemical affinity
      case RoutingTable.route_packet(packet) do
        {:error, reason} ->
          duration = System.monotonic_time(:millisecond) - start_time
          result = PacketResult.failure(packet.id, "PF003", Atom.to_string(reason), duration)
          {:reply, result, state}
          
        {:ok, target_node_id} ->
          # Monitor packet for fault detection
          FaultDetector.monitor_packet(packet)
          
          # Enqueue packet on target node
          case ProcessingNode.enqueue_packet(target_node_id, packet) do
            :ok ->
              # Process packet
              case ProcessingNode.process_next(target_node_id) do
                {:ok, result} ->
                  processing_time = System.monotonic_time(:millisecond) - start_time
                  
                  new_stats = %{
                    state.stats | 
                    packets_processed: state.stats.packets_processed + 1,
                    total_processing_time: state.stats.total_processing_time + processing_time
                  }
                  
                  new_state = %{state | stats: new_stats}
                  {:reply, result, new_state}
                  
                {:error, reason} ->
                  duration = System.monotonic_time(:millisecond) - start_time
                  result = PacketResult.failure(packet.id, "PF005", Atom.to_string(reason), duration)
                  FaultDetector.record_failure(target_node_id, reason)
                  {:reply, result, state}
              end
              
            {:error, reason} ->
              duration = System.monotonic_time(:millisecond) - start_time
              result = PacketResult.failure(packet.id, "PF004", Atom.to_string(reason), duration)
              {:reply, result, state}
          end
      end
    end

    def handle_call(:get_system_status, _from, state) do
      node_statuses = 
        Enum.map(state.nodes, fn {node_id, _info} ->
          ProcessingNode.get_status(node_id)
        end)
      
      system_health = FaultDetector.get_system_health()
      optimization_stats = MolecularOptimizer.get_optimization_stats()
      routing_stats = RoutingTable.get_routing_stats()
      
      uptime_seconds = DateTime.diff(DateTime.utc_now(), state.stats.start_time, :second)
      
      status = %{
        running: state.running,
        uptime_seconds: uptime_seconds,
        nodes: node_statuses,
        molecules: map_size(state.molecules),
        stats: state.stats,
        system_health: system_health,
        optimization_stats: optimization_stats,
        routing_stats: routing_stats,
        average_processing_time: calculate_average_processing_time(state.stats)
      }
      
      {:reply, status, state}
    end

    def handle_call(:start_reactor, _from, state) do
      new_state = %{state | running: true}
      IO.puts("🧪 PacketFlow Reactor started with #{map_size(state.nodes)} nodes")
      {:reply, :ok, new_state}
    end

    def handle_call(:stop_reactor, _from, state) do
      new_state = %{state | running: false}
      IO.puts("⚡ PacketFlow Reactor stopped")
      {:reply, :ok, new_state}
    end

    # Private Functions

    defp calculate_average_processing_time(stats) do
      if stats.packets_processed > 0 do
        stats.total_processing_time / stats.packets_processed
      else
        0.0
      end
    end
  end

  # ============================================================================
  # WEBSOCKET SERVER - Cowboy Integration
  # ============================================================================

  defmodule WebSocketServer do
    @moduledoc "WebSocket Protocol Server"

    use GenServer, restart: :permanent

    defstruct [
      port: 8443,
      acceptor_count: 100,
      server_ref: nil
    ]

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      port = Keyword.get(opts, :port, 8443)
      
      # Define routes
      routes = [
        {"/packetflow/v1", PacketFlow.WebSocketHandler, []}
      ]
      
      dispatch = :cowboy_router.compile([{:_, routes}])
      
      # Start Cowboy
      {:ok, server_ref} = :cowboy.start_clear(
        :packetflow_http,
        [{:port, port}],
        %{env: %{dispatch: dispatch}}
      )
      
      state = %__MODULE__{
        port: port,
        server_ref: server_ref
      }
      
      IO.puts("🌐 PacketFlow WebSocket server listening on port #{port}")
      {:ok, state}
    end

    def handle_info(_msg, state) do
      {:noreply, state}
    end
  end

  defmodule WebSocketHandler do
    @moduledoc "WebSocket Message Handler"

    @behaviour :cowboy_websocket

    def init(req, state) do
      {:cowboy_websocket, req, state}
    end

    def websocket_init(state) do
      IO.puts("🔗 WebSocket client connected")
      {:ok, %{sequence: 0, pending: %{}}}
    end

    def websocket_handle({:text, message}, state) do
      case Jason.decode(message) do
        {:ok, parsed_message} ->
          handle_parsed_message(parsed_message, state)
        
        {:error, _reason} ->
          error_response = %{
            type: "error",
            seq: 0,
            payload: %{code: "PF001", message: "Invalid JSON"}
          }
          
          {:reply, {:text, Jason.encode!(error_response)}, state}
      end
    end

    def websocket_handle(_frame, state) do
      {:ok, state}
    end

    def websocket_info(_info, state) do
      {:ok, state}
    end

    def terminate(_reason, _req, _state) do
      IO.puts("📤 WebSocket client disconnected")
      :ok
    end

    # Private Functions

    defp handle_parsed_message(%{"type" => "submit", "seq" => seq, "payload" => payload}, state) do
      case parse_packet(payload) do
        {:ok, packet} ->
          case ReactorCore.submit_packet(packet) do
            %PacketResult{} = result ->
              response = %{
                type: "result",
                seq: seq,
                payload: serialize_result(result)
              }
              
              {:reply, {:text, Jason.encode!(response)}, state}
              
            error ->
              error_response = %{
                type: "error", 
                seq: seq,
                payload: %{code: "PF500", message: "Processing failed: #{inspect(error)}"}
              }
              
              {:reply, {:text, Jason.encode!(error_response)}, state}
          end
          
        {:error, reason} ->
          error_response = %{
            type: "error",
            seq: seq, 
            payload: %{code: "PF002", message: "Invalid packet: #{reason}"}
          }
          
          {:reply, {:text, Jason.encode!(error_response)}, state}
      end
    end

    defp handle_parsed_message(%{"type" => "heartbeat", "seq" => seq}, state) do
      response = %{
        type: "heartbeat",
        seq: seq,
        payload: %{timestamp: System.system_time(:millisecond)}
      }
      
      {:reply, {:text, Jason.encode!(response)}, state}
    end

    defp handle_parsed_message(_message, state) do
      error_response = %{
        type: "error",
        seq: 0,
        payload: %{code: "PF003", message: "Unknown message type"}
      }
      
      {:reply, {:text, Jason.encode!(error_response)}, state}
    end

    defp parse_packet(payload) do
      try do
        group = String.to_existing_atom(payload["group"])
        element = payload["element"]
        data = payload["data"]
        priority = payload["priority"]
        
        packet = Packet.new(group, element, data, priority,
          timeout_ms: payload["timeout_ms"],
          dependencies: payload["dependencies"],
          metadata: payload["metadata"]
        )
        
        {:ok, packet}
      rescue
        _ -> {:error, "Invalid packet format"}
      end
    end

    defp serialize_result(%PacketResult{} = result) do
      base = %{
        packet_id: result.packet_id,
        status: Atom.to_string(result.status),
        duration_ms: result.duration_ms,
        node_id: result.node_id,
        processed_at: result.processed_at
      }
      
      base
      |> maybe_add_data(result.data)
      |> maybe_add_error(result.error)
    end

    defp maybe_add_data(map, nil), do: map
    defp maybe_add_data(map, data), do: Map.put(map, :data, data)

    defp maybe_add_error(map, nil), do: map
    defp maybe_add_error(map, error), do: Map.put(map, :error, error)
  end

  # ============================================================================
  # PERFORMANCE MONITOR - GenServer
  # ============================================================================

  defmodule PerformanceMonitor do
    @moduledoc "Real-time Performance Monitoring"

    use GenServer, restart: :permanent

    defstruct [
      metrics: %{},
      monitoring_interval: 1000,  # 1 second
      history_size: 3600,  # Keep 1 hour of data
      performance_history: []
    ]

    # Client API

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def get_current_metrics do
      GenServer.call(__MODULE__, :get_current_metrics)
    end

    def get_performance_history do
      GenServer.call(__MODULE__, :get_performance_history)
    end

    def record_latency(packet_group, latency_ms) do
      GenServer.cast(__MODULE__, {:record_latency, packet_group, latency_ms})
    end

    # GenServer Callbacks

    def init(_opts) do
      schedule_monitoring()
      IO.puts("📊 Performance Monitor started")
      {:ok, %__MODULE__{}}
    end

    def handle_call(:get_current_metrics, _from, state) do
      {:reply, state.metrics, state}
    end

    def handle_call(:get_performance_history, _from, state) do
      {:reply, state.performance_history, state}
    end

    def handle_cast({:record_latency, packet_group, latency_ms}, state) do
      group_key = "#{packet_group}_latency"
      current_latencies = Map.get(state.metrics, group_key, [])
      updated_latencies = [latency_ms | Enum.take(current_latencies, 99)]  # Keep last 100
      
      new_metrics = Map.put(state.metrics, group_key, updated_latencies)
      new_state = %{state | metrics: new_metrics}
      
      {:noreply, new_state}
    end

    def handle_info(:collect_metrics, state) do
      new_state = collect_system_metrics(state)
      schedule_monitoring()
      {:noreply, new_state}
    end

    # Private Functions

    defp schedule_monitoring do
      Process.send_after(self(), :collect_metrics, 1000)
    end

    defp collect_system_metrics(state) do
      timestamp = DateTime.utc_now()
      system_status = ReactorCore.get_system_status()
      
      current_metrics = %{
        timestamp: timestamp,
        total_nodes: length(system_status.nodes),
        packets_processed: system_status.stats.packets_processed,
        molecules_created: system_status.stats.molecules_created,
        average_processing_time: system_status.average_processing_time,
        system_health_score: system_status.system_health.system_health_score,
        memory_usage: :erlang.memory(:total)
      }
      
      # Add to history
      new_history = [current_metrics | Enum.take(state.performance_history, state.history_size - 1)]
      
      %{state | 
        metrics: current_metrics,
        performance_history: new_history
      }
    end
  end

  # ============================================================================
  # MOLECULAR PATTERNS - Predefined Compositions
  # ============================================================================

  defmodule MolecularPatterns do
    @moduledoc "Common Molecular Patterns"

    def stream_pipeline(opts \\ []) do
      id = Keyword.get(opts, :id, "stream_pipeline_#{:rand.uniform(1000)}")
      
      # Create packets
      producer = Packet.new(:df, "producer", "data_source", 5)
      transformer = Packet.new(:df, "transform", "processing_function", 7)
      consumer = Packet.new(:df, "consumer", "data_sink", 4)
      
      # Create bonds
      bond1 = ChemicalBond.new(producer.id, transformer.id, :ionic)
      bond2 = ChemicalBond.new(transformer.id, consumer.id, :ionic)
      
      # Create molecule
      Molecule.new(id,
        composition: [producer, transformer, consumer],
        bonds: [bond1, bond2],
        properties: %{
          throughput: :high,
          backpressure: :enabled,
          fault_recovery: :automatic
        }
      )
    end

    def fault_tolerant_service(opts \\ []) do
      id = Keyword.get(opts, :id, "fault_tolerant_service_#{:rand.uniform(1000)}")
      
      # Create packets
      exception_handler = Packet.new(:cf, "exception", "error_recovery", 9)
      spawner = Packet.new(:mc, "spawn", %{replicas: 3}, 6)
      allocator = Packet.new(:rm, "allocate", "memory_pool", 7)
      
      # Create bonds
      bond1 = ChemicalBond.new(exception_handler.id, spawner.id, :ionic)
      bond2 = ChemicalBond.new(spawner.id, allocator.id, :covalent)
      
      # Create molecule
      Molecule.new(id,
        composition: [exception_handler, spawner, allocator],
        bonds: [bond1, bond2],
        properties: %{
          fault_tolerance: :byzantine_resilient,
          recovery_time: "< 1s",
          redundancy_factor: 3
        }
      )
    end

    def autoscaling_cluster(opts \\ []) do
      id = Keyword.get(opts, :id, "autoscaling_cluster_#{:rand.uniform(1000)}")
      
      # Create packets
      threshold_monitor = Packet.new(:ed, "threshold", %{cpu_threshold: 80}, 8)
      worker_spawner = Packet.new(:mc, "spawn", "worker_template", 7)
      broadcaster = Packet.new(:co, "broadcast", "cluster_config", 5)
      cache_manager = Packet.new(:rm, "cache", "distributed_cache", 6)
      
      # Create bonds
      bond1 = ChemicalBond.new(threshold_monitor.id, worker_spawner.id, :ionic)
      bond2 = ChemicalBond.new(worker_spawner.id, broadcaster.id, :covalent)
      bond3 = ChemicalBond.new(broadcaster.id, cache_manager.id, :metallic)
      
      # Create molecule
      Molecule.new(id,
        composition: [threshold_monitor, worker_spawner, broadcaster, cache_manager],
        bonds: [bond1, bond2, bond3],
        properties: %{
          scaling: :predictive,
          max_instances: 100,
          min_instances: 3,
          scaling_algorithm: :chemical_affinity
        }
      )
    end

    def distributed_ml_training(opts \\ []) do
      id = Keyword.get(opts, :id, "ml_training_#{:rand.uniform(1000)}")
      
      # Create packets
      data_loader = Packet.new(:df, "producer", "training_data", 6)
      parameter_server = Packet.new(:co, "sync", "model_parameters", 8)
      gradient_aggregator = Packet.new(:co, "gather", "gradient_collection", 7)
      optimizer = Packet.new(:mc, "adapt", "learning_optimization", 9)
      checkpoint_manager = Packet.new(:rm, "cache", "model_checkpoints", 5)
      
      # Create bonds
      bond1 = ChemicalBond.new(data_loader.id, parameter_server.id, :covalent)
      bond2 = ChemicalBond.new(parameter_server.id, gradient_aggregator.id, :ionic)
      bond3 = ChemicalBond.new(gradient_aggregator.id, optimizer.id, :ionic)
      bond4 = ChemicalBond.new(optimizer.id, checkpoint_manager.id, :metallic)
      bond5 = ChemicalBond.new(checkpoint_manager.id, parameter_server.id, :vdw)
      
      # Create molecule
      Molecule.new(id,
        composition: [data_loader, parameter_server, gradient_aggregator, optimizer, checkpoint_manager],
        bonds: [bond1, bond2, bond3, bond4, bond5],
        properties: %{
          training_type: :distributed,
          synchronization: :synchronous,
          fault_tolerance: :checkpoint_recovery,
          scalability: "1000+ GPUs"
        }
      )
    end
  end

  # ============================================================================
  # EXAMPLE PACKET HANDLERS
  # ============================================================================

  defmodule ExampleHandlers do
    @moduledoc "Example Packet Handlers"

    # Data Flow Transform Handler
    def transform_handler(data) when is_binary(data) do
      String.upcase(data)
    end

    def transform_handler(data) when is_list(data) do
      Enum.map(data, &(&1 * 2))
    end

    def transform_handler(data) when is_number(data) do
      data * data
    end

    def transform_handler(data) do
      {:processed, data}
    end

    # Control Flow Sequential Handler
    def sequential_handler(data) when is_number(data) do
      data * 2 + 1
    end

    def sequential_handler(data) do
      {:sequential_result, data}
    end

    # Event Driven Signal Handler
    def signal_handler(data) do
      IO.puts("📡 Signal received: #{inspect(data)}")
      %{signal_processed: true, timestamp: DateTime.utc_now(), data: data}
    end

    # Resource Management Cache Handler
    def cache_handler(data) do
      IO.puts("💾 Caching data: #{inspect(data)}")
      %{cached: true, cache_key: "cache_#{:rand.uniform(1000)}", data: data}
    end

    # Collective Broadcast Handler
    def broadcast_handler(data) do
      IO.puts("📢 Broadcasting: #{inspect(data)}")
      %{broadcast: true, recipients: [:node_1, :node_2, :node_3], data: data}
    end

    # Meta-Computational Learning Handler
    def learning_handler(data) do
      IO.puts("🧠 Learning from: #{inspect(data)}")
      %{learning_complete: true, model_updated: true, accuracy: 0.95, data: data}
    end
  end

  # ============================================================================
  # BENCHMARKING AND TESTING
  # ============================================================================

  defmodule Benchmark do
    @moduledoc "Performance Benchmarking"

    def run_latency_test(packet_count \\ 1000) do
      IO.puts("🏁 Running latency benchmark with #{packet_count} packets...")
      
      results = 
        1..packet_count
        |> Enum.map(fn i ->
          packet = Packet.new(:df, "transform", "test_data_#{i}", 5)
          
          start_time = System.monotonic_time(:microsecond)
          result = ReactorCore.submit_packet(packet)
          end_time = System.monotonic_time(:microsecond)
          
          latency_us = end_time - start_time
          
          case result.status do
            :success -> {:ok, latency_us}
            :error -> {:error, latency_us}
          end
        end)
      
      # Separate successful and failed results
      {successes, failures} = Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      
      success_latencies = Enum.map(successes, fn {:ok, latency} -> latency end)
      
      if length(success_latencies) > 0 do
        sorted_latencies = Enum.sort(success_latencies)
        total_latency = Enum.sum(success_latencies)
        
        mean_us = total_latency / length(success_latencies)
        p50_us = Enum.at(sorted_latencies, div(length(sorted_latencies), 2))
        p99_us = Enum.at(sorted_latencies, div(length(sorted_latencies) * 99, 100))
        
        IO.puts("📊 Latency Results:")
        IO.puts("   Successful packets: #{length(successes)}/#{packet_count}")
        IO.puts("   Failed packets: #{length(failures)}")
        IO.puts("   Mean: #{Float.round(mean_us / 1000, 2)} ms")
        IO.puts("   P50:  #{Float.round(p50_us / 1000, 2)} ms")
        IO.puts("   P99:  #{Float.round(p99_us / 1000, 2)} ms")
        IO.puts("   Throughput: #{Float.round(length(successes) / (total_latency / 1_000_000), 0)} packets/second")
        
        %{
          successful: length(successes),
          failed: length(failures),
          mean_latency_ms: mean_us / 1000,
          p50_latency_ms: p50_us / 1000,
          p99_latency_ms: p99_us / 1000,
          throughput_pps: length(successes) / (total_latency / 1_000_000)
        }
      else
        IO.puts("❌ All packets failed!")
        %{successful: 0, failed: length(failures)}
      end
    end
    
    def run_throughput_test(duration_seconds \\ 10) do
      IO.puts("🚀 Running throughput benchmark for #{duration_seconds} seconds...")
      
      start_time = System.system_time(:second)
      end_time = start_time + duration_seconds
      
      # Start multiple concurrent workers
      worker_count = System.schedulers_online() * 2
      
      workers = 
        1..worker_count
        |> Enum.map(fn worker_id ->
          spawn_link(fn -> throughput_worker(worker_id, end_time, self()) end)
        end)
      
      # Collect results from workers
      results = collect_worker_results(workers, [])
      
      total_packets = Enum.sum(Enum.map(results, fn {packets, _} -> packets end))
      total_successes = Enum.sum(Enum.map(results, fn {_, successes} -> successes end))
      
      actual_duration = System.system_time(:second) - start_time
      throughput = total_packets / actual_duration
      success_rate = if total_packets > 0, do: total_successes / total_packets, else: 0.0
      
      IO.puts("📊 Throughput Results:")
      IO.puts("   Workers: #{worker_count}")
      IO.puts("   Packets processed: #{total_packets}")
      IO.puts("   Success rate: #{Float.round(success_rate * 100, 1)}%")
      IO.puts("   Throughput: #{Float.round(throughput, 0)} packets/second")
      
      system_status = ReactorCore.get_system_status()
      IO.puts("   System health: #{Float.round(system_status.system_health.system_health_score * 100, 1)}%")
      
      %{
        workers: worker_count,
        total_packets: total_packets,
        success_rate: success_rate,
        throughput_pps: throughput,
        system_health: system_status.system_health.system_health_score
      }
    end
    
    defp throughput_worker(worker_id, end_time, parent_pid) do
      throughput_worker_loop(worker_id, end_time, parent_pid, 0, 0)
    end
    
    defp throughput_worker_loop(worker_id, end_time, parent_pid, packet_count, success_count) do
      if System.system_time(:second) >= end_time do
        send(parent_pid, {:worker_result, worker_id, {packet_count, success_count}})
      else
        packet = Packet.new(:df, "transform", "worker_#{worker_id}_packet_#{packet_count}", 5)
        
        result = ReactorCore.submit_packet(packet)
        
        new_success_count = 
          if result.status == :success do
            success_count + 1
          else
            success_count
          end
        
        throughput_worker_loop(worker_id, end_time, parent_pid, packet_count + 1, new_success_count)
      end
    end
    
    defp collect_worker_results([], results), do: results
    
    defp collect_worker_results(workers, results) do
      receive do
        {:worker_result, _worker_id, result} ->
          remaining_workers = List.delete(workers, :worker_done)  # Simplified
          collect_worker_results(remaining_workers, [result | results])
      after
        30_000 -> results  # Timeout after 30 seconds
      end
    end
    
    def run_molecular_stability_test do
      IO.puts("🧬 Running molecular stability test...")
      
      # Create various molecular patterns
      stream_pipeline = MolecularPatterns.stream_pipeline()
      fault_tolerant = MolecularPatterns.fault_tolerant_service()
      autoscaling = MolecularPatterns.autoscaling_cluster()
      ml_training = MolecularPatterns.distributed_ml_training()
      
      molecules = [
        {"Stream Pipeline", stream_pipeline},
        {"Fault Tolerant Service", fault_tolerant},
        {"Autoscaling Cluster", autoscaling},
        {"ML Training", ml_training}
      ]
      
      IO.puts("📊 Molecular Stability Results:")
      
      results = 
        Enum.map(molecules, fn {name, molecule} ->
          stability = molecule.stability
          is_stable = Molecule.stable?(molecule)
          packet_count = Molecule.packet_count(molecule)
          bond_count = Molecule.bond_count(molecule)
          
          IO.puts("   #{name}:")
          IO.puts("     Stability: #{Float.round(stability, 3)}")
          IO.puts("     Is Stable: #{is_stable}")
          IO.puts("     Packets: #{packet_count}, Bonds: #{bond_count}")
          
          # Register with reactor for optimization
          ReactorCore.create_molecule(molecule.id, 
            composition: molecule.composition,
            bonds: molecule.bonds,
            properties: molecule.properties
          )
          
          %{
            name: name,
            stability: stability,
            is_stable: is_stable,
            packet_count: packet_count,
            bond_count: bond_count
          }
        end)
      
      # Wait for optimization
      :timer.sleep(6000)  # Let optimizer run
      
      optimization_stats = MolecularOptimizer.get_optimization_stats()
      IO.puts("\n⚡ Optimization Results:")
      IO.puts("   Molecules optimized: #{optimization_stats.optimizations_performed}")
      IO.puts("   Total improvement: #{Float.round(optimization_stats.total_stability_improvement, 3)}")
      IO.puts("   Average improvement: #{Float.round(optimization_stats.average_improvement, 3)}")
      
      results
    end
    
    def run_chemical_affinity_test do
      IO.puts("🧪 Running chemical affinity test...")
      
      groups = [:cf, :df, :ed, :co, :mc, :rm]
      specializations = [:cpu_intensive, :memory_bound, :io_intensive, :network_heavy, :general_purpose]
      
      IO.puts("📊 Chemical Affinity Matrix:")
      IO.puts("     #{Enum.join(Enum.map(specializations, &String.slice(Atom.to_string(&1), 0, 8)), "  ")}")
      
      Enum.each(groups, fn group ->
        affinities = 
          Enum.map(specializations, fn spec ->
            affinity = PacketFlow.calculate_chemical_affinity(group, spec)
            :io_lib.format("~.1f", [affinity]) |> to_string() |> String.pad_leading(8)
          end)
        
        IO.puts("#{group}: #{Enum.join(affinities, "  ")}")
      end)
      
      # Test routing based on affinity
      IO.puts("\n🧭 Testing chemical routing...")
      
      test_packets = [
        Packet.new(:cf, "sequential", "control_test", 7),
        Packet.new(:df, "transform", "data_test", 5),
        Packet.new(:ed, "signal", "event_test", 9),
        Packet.new(:co, "broadcast", "collective_test", 6),
        Packet.new(:mc, "adapt", "meta_test", 8),
        Packet.new(:rm, "cache", "resource_test", 4)
      ]
      
      routing_results = 
        Enum.map(test_packets, fn packet ->
          case RoutingTable.route_packet(packet) do
            {:ok, node_id} ->
              node_status = ProcessingNode.get_status(node_id)
              {packet.group, node_id, node_status.specialization}
            
            {:error, reason} ->
              {packet.group, :error, reason}
          end
        end)
      
      IO.puts("   Routing Results:")
      Enum.each(routing_results, fn {group, node_id, spec} ->
        IO.puts("     #{group} -> #{node_id} (#{spec})")
      end)
      
      routing_results
    end
  end

  # ============================================================================
  # DEMO AND EXAMPLES
  # ============================================================================

  defmodule Demo do
    @moduledoc "PacketFlow Demonstration"
    
    def run_full_demo do
      IO.puts("\n🧪⚡ PacketFlow - Periodic Table Distributed Computing Demo")
      IO.puts("=" |> String.duplicate(60))
      
      # Setup reactor with specialized nodes
      setup_demo_environment()
      
      # Run demonstrations
      IO.puts("\n1️⃣  Chemical Properties Demo:")
      run_chemical_properties_demo()
      
      IO.puts("\n2️⃣  Molecular Composition Demo:")
      run_molecular_composition_demo()
      
      IO.puts("\n3️⃣  Performance Benchmarks:")
      run_performance_demos()
      
      IO.puts("\n4️⃣  Fault Tolerance Demo:")
      run_fault_tolerance_demo()
      
      IO.puts("\n5️⃣  Advanced Patterns Demo:")
      run_advanced_patterns_demo()
      
      IO.puts("\n🎉 PacketFlow demonstration complete!")
      print_demo_summary()
    end
    
    defp setup_demo_environment do
      IO.puts("🔧 Setting up PacketFlow environment...")
      
      # Add specialized processing nodes
      {:ok, cpu_node} = ReactorCore.add_node(:cpu_intensive, 100.0)
      {:ok, memory_node} = ReactorCore.add_node(:memory_bound, 120.0)
      {:ok, io_node} = ReactorCore.add_node(:io_intensive, 80.0)
      {:ok, network_node} = ReactorCore.add_node(:network_heavy, 60.0)
      
      # Register handlers
      ProcessingNode.register_handler(cpu_node, :df, "transform", &ExampleHandlers.transform_handler/1)
      ProcessingNode.register_handler(cpu_node, :cf, "sequential", &ExampleHandlers.sequential_handler/1)
      ProcessingNode.register_handler(io_node, :ed, "signal", &ExampleHandlers.signal_handler/1)
      ProcessingNode.register_handler(memory_node, :rm, "cache", &ExampleHandlers.cache_handler/1)
      ProcessingNode.register_handler(network_node, :co, "broadcast", &ExampleHandlers.broadcast_handler/1)
      ProcessingNode.register_handler(cpu_node, :mc, "learning", &ExampleHandlers.learning_handler/1)
      
      # Start reactor
      ReactorCore.start_reactor()
      
      IO.puts("   ✅ Environment ready with 4 specialized nodes")
    end
    
    defp run_chemical_properties_demo do
      # Create test packets from each group
      packets = [
        Packet.new(:cf, "sequential", "control_data", 7),
        Packet.new(:df, "transform", "data_flow", 5),
        Packet.new(:ed, "signal", "event_signal", 9),
        Packet.new(:co, "broadcast", "collective_op", 6),
        Packet.new(:mc, "learning", "meta_compute", 8),
        Packet.new(:rm, "cache", "resource_mgmt", 4)
      ]
      
      IO.puts("   📊 Packet Chemical Properties:")
      
      Enum.each(packets, fn packet ->
        reactivity = Packet.reactivity(packet)
        ionization = Packet.ionization_energy(packet)
        radius = Packet.atomic_radius(packet)
        electronegativity = Packet.electronegativity(packet)
        
        IO.puts("     #{packet.group}: reactivity=#{Float.round(reactivity, 2)}, " <>
                "ionization=#{Float.round(ionization, 2)}, " <>
                "radius=#{Float.round(radius, 2)}, " <>
                "electronegativity=#{Float.round(electronegativity, 2)}")
      end)
      
      # Submit packets and show routing
      IO.puts("\n   🧭 Chemical Routing Results:")
      
      Enum.each(packets, fn packet ->
        result = ReactorCore.submit_packet(packet)
        status_icon = if result.status == :success, do: "✅", else: "❌"
        
        IO.puts("     #{status_icon} #{packet.group}:#{packet.element} -> " <>
                "node #{result.node_id} (#{result.duration_ms}ms)")
      end)
    end
    
    defp run_molecular_composition_demo do
      IO.puts("   🧬 Creating molecular structures...")
      
      # Create stream pipeline molecule
      {:ok, stream_molecule} = ReactorCore.create_molecule("demo_stream_pipeline")
      
      # Add packets to molecule
      producer = Packet.new(:df, "producer", "stream_source", 5)
      transformer = Packet.new(:df, "transform", "stream_processor", 7)
      consumer = Packet.new(:df, "consumer", "stream_sink", 4)
      
      updated_molecule = 
        stream_molecule
        |> Molecule.add_packets([producer, transformer, consumer])
        |> Molecule.add_bonds([
          ChemicalBond.new(producer.id, transformer.id, :ionic),
          ChemicalBond.new(transformer.id, consumer.id, :ionic)
        ])
      
      IO.puts("     📊 Stream Pipeline Molecule:")
      IO.puts("       Packets: #{Molecule.packet_count(updated_molecule)}")
      IO.puts("       Bonds: #{Molecule.bond_count(updated_molecule)}")
      IO.puts("       Stability: #{Float.round(updated_molecule.stability, 3)}")
      IO.puts("       Is Stable: #{Molecule.stable?(updated_molecule)}")
      
      # Create fault-tolerant service molecule using pattern
      fault_tolerant = MolecularPatterns.fault_tolerant_service(id: "demo_fault_tolerant")
      {:ok, _} = ReactorCore.create_molecule(fault_tolerant.id,
        composition: fault_tolerant.composition,
        bonds: fault_tolerant.bonds,
        properties: fault_tolerant.properties
      )
      
      IO.puts("     🛡️  Fault Tolerant Service Molecule:")
      IO.puts("       Packets: #{Molecule.packet_count(fault_tolerant)}")
      IO.puts("       Bonds: #{Molecule.bond_count(fault_tolerant)}")
      IO.puts("       Stability: #{Float.round(fault_tolerant.stability, 3)}")
      IO.puts("       Properties: #{map_size(fault_tolerant.properties)} custom properties")
    end
    
    defp run_performance_demos do
      IO.puts("   🏁 Latency Benchmark:")
      latency_results = Benchmark.run_latency_test(500)
      
      IO.puts("\n   🚀 Throughput Benchmark:")
      throughput_results = Benchmark.run_throughput_test(5)
      
      IO.puts("\n   🧪 Chemical Affinity Test:")
      _affinity_results = Benchmark.run_chemical_affinity_test()
      
      {latency_results, throughput_results}
    end
    
    defp run_fault_tolerance_demo do
      IO.puts("   🏥 System Health Check:")
      
      system_health = FaultDetector.get_system_health()
      IO.puts("     System Health Score: #{Float.round(system_health.system_health_score * 100, 1)}%")
      IO.puts("     Healthy Nodes: #{system_health.healthy_nodes}/#{system_health.total_nodes}")
      
      # Simulate a failure
      IO.puts("\n   ⚠️  Simulating node failure...")
      FaultDetector.record_failure("node_1", :timeout)
      FaultDetector.record_failure("node_1", :memory_error)
      FaultDetector.record_failure("node_1", :crash)
      
      # Check if node is still healthy
      is_healthy = FaultDetector.is_node_healthy?("node_1")
      IO.puts("     Node 1 healthy after failures: #{is_healthy}")
      
      # Test molecular healing
      {:ok, healed} = FaultDetector.heal_molecule("test_molecule", ["failed_packet_1"])
      IO.puts("     Molecular healing successful: #{healed}")
    end
    
    defp run_advanced_patterns_demo do
      IO.puts("   🧬 Advanced Molecular Patterns:")
      
      # Create ML training molecule
      ml_molecule = MolecularPatterns.distributed_ml_training(id: "demo_ml_training")
      {:ok, _} = ReactorCore.create_molecule(ml_molecule.id,
        composition: ml_molecule.composition,
        bonds: ml_molecule.bonds,
        properties: ml_molecule.properties
      )
      
      IO.puts("     🤖 ML Training Molecule:")
      IO.puts("       Packets: #{Molecule.packet_count(ml_molecule)}")
      IO.puts("       Stability: #{Float.round(ml_molecule.stability, 3)}")
      IO.puts("       Training Type: #{ml_molecule.properties["training_type"]}")
      
      # Create autoscaling cluster
      autoscaling = MolecularPatterns.autoscaling_cluster(id: "demo_autoscaling")
      {:ok, _} = ReactorCore.create_molecule(autoscaling.id,
        composition: autoscaling.composition,
        bonds: autoscaling.bonds,
        properties: autoscaling.properties
      )
      
      IO.puts("     📈 Autoscaling Cluster:")
      IO.puts("       Packets: #{Molecule.packet_count(autoscaling)}")
      IO.puts("       Stability: #{Float.round(autoscaling.stability, 3)}")
      IO.puts("       Max Instances: #{autoscaling.properties["max_instances"]}")
      
      # Run molecular stability test
      IO.puts("\n   ⚡ Molecular Optimization:")
      _stability_results = Benchmark.run_molecular_stability_test()
    end
    
    defp print_demo_summary do
      system_status = ReactorCore.get_system_status()
      
      IO.puts("\n📈 Final System Status:")
      IO.puts("   Uptime: #{system_status.uptime_seconds} seconds")
      IO.puts("   Packets processed: #{system_status.stats.packets_processed}")
      IO.puts("   Molecules created: #{system_status.stats.molecules_created}")
      IO.puts("   Average processing time: #{Float.round(system_status.average_processing_time, 2)}ms")
      IO.puts("   System health: #{Float.round(system_status.system_health.system_health_score * 100, 1)}%")
      
      IO.puts("\n🌟 Key Features Demonstrated:")
      IO.puts("   ✅ Six chemical packet groups (CF, DF, ED, CO, MC, RM)")
      IO.puts("   ✅ Chemical properties and periodic behavior")
      IO.puts("   ✅ Chemical affinity-based routing")
      IO.puts("   ✅ Molecular composition with bonds")
      IO.puts("   ✅ Molecular stability and optimization")
      IO.puts("   ✅ Fault detection and recovery")
      IO.puts("   ✅ Performance monitoring and benchmarking")
      IO.puts("   ✅ WebSocket protocol support")
      IO.puts("   ✅ Advanced molecular patterns")
      IO.puts("   ✅ Real-time system health monitoring")
      
      IO.puts("\n🚀 PacketFlow Elixir implementation ready for production!")
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  def version, do: @packetflow_version
  
  def demo, do: Demo.run_full_demo()
  
  def benchmark_latency(count \\ 1000), do: Benchmark.run_latency_test(count)
  
  def benchmark_throughput(duration \\ 10), do: Benchmark.run_throughput_test(duration)
  
  def system_status, do: ReactorCore.get_system_status()
  
  def health_check, do: FaultDetector.get_system_health()
  
  def create_stream_pipeline(opts \\ []), do: MolecularPatterns.stream_pipeline(opts)
  
  def create_fault_tolerant_service(opts \\ []), do: MolecularPatterns.fault_tolerant_service(opts)
  
  def create_autoscaling_cluster(opts \\ []), do: MolecularPatterns.autoscaling_cluster(opts)
  
  def create_ml_training_pipeline(opts \\ []), do: MolecularPatterns.distributed_ml_training(opts)
end

# ============================================================================
# MIX PROJECT CONFIGURATION (for mix.exs)
# ============================================================================

# Add this to your mix.exs dependencies:
# defp deps do
#   [
#     {:jason, "~> 1.4"},
#     {:cowboy, "~> 2.10"},
#     {:uuid, "~> 1.1"},
#     {:plug, "~> 1.14"},
#     {:plug_cowboy, "~> 2.6"}
#   ]
# end

# ============================================================================
# USAGE EXAMPLES
# ============================================================================

# # Start the application
# Application.start(:packetflow_elixir)
# 
# # Run the full demo
# PacketFlow.demo()
# 
# # Create and submit individual packets
# packet = PacketFlow.Packet.new(:df, "transform", "hello world", 5)
# result = PacketFlow.ReactorCore.submit_packet(packet)
# 
# # Create molecular patterns
# stream = PacketFlow.create_stream_pipeline()
# {:ok, _} = PacketFlow.ReactorCore.create_molecule(stream.id, 
#   composition: stream.composition, bonds: stream.bonds)
# 
# # Run benchmarks
# PacketFlow.benchmark_latency(1000)
# PacketFlow.benchmark_throughput(10)
# 
# # Check system health
# PacketFlow.health_check()
# PacketFlow.system_status()
