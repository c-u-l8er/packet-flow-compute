# PacketFlow Capability Composition Macro Design

## Overview

This design extends PacketFlow's capability system with powerful composition macros that allow developers to declaratively define complex workflows from simple capabilities while maintaining full observability, error handling, and distributed tracing.

## Core Composition Macros

### 1. Pipeline Composition (`pipeline`)

Sequential execution with data flow between steps.

```elixir
capability :user_onboarding do
  requires [:email, :password, :profile_data]
  provides [:user_account, :onboarding_status]
  
  pipeline do
    step :validate_email, 
      from: [:email],
      to: [:validated_email, :email_domain]
    
    step :check_existing_user,
      from: [:validated_email], 
      to: [:user_exists, :existing_user_id]
    
    branch :user_exists do
      when true -> step :handle_existing_user, 
        from: [:existing_user_id],
        to: [:user_account]
        
      when false -> sequence do
        step :create_user_account,
          from: [:validated_email, :password],
          to: [:user_account, :account_id]
          
        step :setup_user_profile,
          from: [:account_id, :profile_data],
          to: [:user_profile]
          
        step :send_welcome_email,
          from: [:user_account, :email_domain],
          to: [:email_sent]
      end
    end
    
    step :finalize_onboarding,
      from: [:user_account],
      to: [:onboarding_status]
  end
  
  # Error handling for the entire pipeline
  rescue do
    ValidationError -> {:error, :invalid_input}
    ExistingUserError -> {:ok, :user_already_exists}
    _ -> {:error, :onboarding_failed}
  end
end
```

### 2. Parallel Composition (`parallel`)

Concurrent execution with result aggregation.

```elixir
capability :user_dashboard_data do
  requires [:user_id]
  provides [:dashboard_data]
  
  parallel do
    # All execute concurrently
    branch :user_info, 
      capability: :fetch_user_details,
      from: [:user_id],
      to: [:user_profile, :user_settings]
    
    branch :analytics,
      capability: :fetch_user_analytics, 
      from: [:user_id],
      to: [:page_views, :activity_score]
      
    branch :notifications,
      capability: :fetch_user_notifications,
      from: [:user_id], 
      to: [:unread_count, :recent_notifications]
      
    branch :permissions,
      capability: :fetch_user_permissions,
      from: [:user_id],
      to: [:roles, :feature_flags]
  end
  
  # Combine results from all branches
  combine fn results ->
    %{
      dashboard_data: %{
        user: results.user_info,
        stats: results.analytics,
        alerts: results.notifications,
        access: results.permissions
      }
    }
  end
  
  # Timeout and error handling
  timeout 5_000
  
  partial_failure :continue  # Continue even if some branches fail
end
```

### 3. Conditional Composition (`conditional`)

Dynamic execution based on runtime conditions.

```elixir
capability :process_payment do
  requires [:user_id, :amount, :payment_method]
  provides [:transaction_result, :receipt]
  
  conditional do
    # Check user's payment tier
    condition :payment_tier do
      step :determine_user_tier, 
        from: [:user_id],
        to: [:tier, :tier_limits]
    end
    
    when :tier == :premium do
      sequence do
        step :validate_premium_payment,
          from: [:amount, :payment_method, :tier_limits],
          to: [:validated_payment]
          
        step :process_premium_transaction,
          from: [:validated_payment, :user_id],
          to: [:transaction_result]
          
        step :generate_premium_receipt,
          from: [:transaction_result],
          to: [:receipt]
      end
    end
    
    when :tier == :standard do
      sequence do
        step :check_standard_limits,
          from: [:amount, :tier_limits],
          to: [:within_limits]
          
        branch :within_limits do
          when true -> step :process_standard_transaction,
            from: [:amount, :payment_method, :user_id],
            to: [:transaction_result]
            
          when false -> step :request_payment_upgrade,
            from: [:user_id, :amount],
            to: [:upgrade_offer]
        end
      end
    end
    
    otherwise do
      step :handle_unknown_tier,
        from: [:user_id, :tier],
        to: [:error_result]
    end
  end
end
```

### 4. Event-Driven Composition (`event_driven`)

Reactive composition based on events and state changes.

```elixir
capability :user_lifecycle_manager do
  requires [:user_id, :trigger_event]
  provides [:lifecycle_actions, :next_state]
  
  event_driven do
    # Define state machine
    states [:new, :active, :inactive, :suspended, :deleted]
    initial_state :new
    
    # State determination
    determine_state do
      step :get_current_user_state,
        from: [:user_id],
        to: [:current_state, :last_activity]
    end
    
    # Event handlers for each state
    on_event :user_login do
      from_state :new do
        parallel do
          branch :activation,
            capability: :activate_user_account,
            from: [:user_id],
            to: [:activated_account]
            
          branch :analytics,
            capability: :track_first_login,
            from: [:user_id],
            to: [:analytics_tracked]
        end
        
        transition_to :active
      end
      
      from_state :inactive do
        step :reactivate_user,
          from: [:user_id, :last_activity],
          to: [:reactivation_result]
          
        transition_to :active
      end
      
      from_state [:suspended, :deleted] do
        step :handle_suspended_login,
          from: [:user_id, :current_state],
          to: [:error_response]
          
        # No state transition
      end
    end
    
    on_event :user_inactivity_detected do
      from_state :active do
        conditional do
          condition :inactivity_duration do
            step :calculate_inactivity,
              from: [:user_id, :last_activity],
              to: [:days_inactive]
          end
          
          when :days_inactive > 30 do
            step :suspend_user,
              from: [:user_id],
              to: [:suspension_result]
              
            transition_to :suspended
          end
          
          when :days_inactive > 7 do
            step :mark_user_inactive,
              from: [:user_id],
              to: [:inactive_result]
              
            transition_to :inactive
          end
        end
      end
    end
  end
  
  # Final result aggregation
  finalize fn state_data ->
    %{
      lifecycle_actions: state_data.actions_taken,
      next_state: state_data.final_state
    }
  end
end
```

### 5. Loop Composition (`loop`)

Iterative execution with break conditions.

```elixir
capability :batch_user_processing do
  requires [:user_batch_id, :processing_options]
  provides [:processed_users, :processing_summary]
  
  loop do
    # Initialize loop state
    initialize do
      step :fetch_user_batch,
        from: [:user_batch_id],
        to: [:user_list, :total_count]
        
      step :setup_processing_context,
        from: [:processing_options],
        to: [:batch_context]
    end
    
    # Iterate over users
    iterate_over :user_list, as: :current_user do
      sequence do
        step :validate_user_data,
          from: [:current_user],
          to: [:validation_result]
          
        conditional do
          when :validation_result.valid? do
            step :process_user,
              from: [:current_user, :batch_context],
              to: [:processed_user]
          end
          
          otherwise do
            step :log_validation_error,
              from: [:current_user, :validation_result],
              to: [:error_logged]
          end
        end
        
        step :update_progress,
          from: [:current_user, :total_count],
          to: [:progress_updated]
      end
      
      # Break conditions
      break_when fn loop_state ->
        loop_state.errors_count > 10 or 
        loop_state.processed_count >= 1000
      end
      
      # Delay between iterations
      delay 100  # milliseconds
    end
    
    # Finalize loop
    finalize do
      step :generate_processing_summary,
        from: [:processed_count, :errors_count, :total_count],
        to: [:processing_summary]
    end
  end
end
```

### 6. Retry Composition (`retry`)

Automatic retry with backoff strategies.

```elixir
capability :reliable_external_api_call do
  requires [:api_endpoint, :request_data]
  provides [:api_response, :retry_metadata]
  
  retry do
    # Main execution
    attempt do
      step :prepare_api_request,
        from: [:api_endpoint, :request_data],
        to: [:prepared_request]
        
      step :make_api_call,
        from: [:prepared_request],
        to: [:api_response]
        
      step :validate_api_response,
        from: [:api_response],
        to: [:validated_response]
    end
    
    # Retry configuration
    max_attempts 3
    backoff :exponential, base: 1000, max: 10_000
    
    # Retry conditions
    retry_when do
      error_type in [HTTPError, TimeoutError] -> true
      status_code in [429, 500, 502, 503, 504] -> true
      _ -> false
    end
    
    # Circuit breaker
    circuit_breaker do
      failure_threshold 5
      recovery_timeout 30_000
      half_open_max_calls 3
    end
    
    # Fallback on final failure
    fallback do
      step :use_cached_response,
        from: [:api_endpoint],
        to: [:cached_response]
        
      step :log_fallback_used,
        from: [:api_endpoint, :retry_metadata],
        to: [:fallback_logged]
    end
  end
end
```

### 7. Map-Reduce Composition (`map_reduce`)

Distributed processing over collections.

```elixir
capability :analyze_user_behavior_patterns do
  requires [:date_range, :user_segments]
  provides [:behavior_analysis, :pattern_insights]
  
  map_reduce do
    # Map phase - process each user segment
    map over: :user_segments, as: :segment do
      parallel do
        branch :user_data,
          capability: :fetch_segment_users,
          from: [:segment, :date_range],
          to: [:users_in_segment]
          
        branch :activity_data,
          capability: :fetch_segment_activity,
          from: [:segment, :date_range], 
          to: [:activity_events]
      end
      
      sequence do
        step :analyze_segment_behavior,
          from: [:users_in_segment, :activity_events],
          to: [:segment_analysis]
          
        step :extract_patterns,
          from: [:segment_analysis],
          to: [:segment_patterns]
      end
      
      emit [:segment_patterns]  # Output from map phase
    end
    
    # Reduce phase - aggregate all segment patterns
    reduce do
      step :combine_segment_patterns,
        from: [:all_segment_patterns],  # Automatic collection
        to: [:combined_patterns]
        
      step :identify_cross_segment_trends,
        from: [:combined_patterns],
        to: [:cross_segment_trends]
        
      step :generate_insights,
        from: [:combined_patterns, :cross_segment_trends],
        to: [:pattern_insights]
    end
    
    # Partitioning strategy
    partition_by :segment_size
    
    # Concurrency control
    max_concurrent_maps 5
    chunk_size 100
  end
end
```

## Implementation Architecture

### Macro Expansion Strategy

Each composition macro expands into a state machine that:

1. **Validates composition structure** at compile time
2. **Generates execution plan** with dependency graph
3. **Creates monitoring hooks** for each step
4. **Handles error propagation** according to composition type
5. **Manages context flow** between steps

### Example Expansion

```elixir
# This capability definition:
capability :simple_pipeline do
  pipeline do
    step :step_a, from: [:input], to: [:intermediate]
    step :step_b, from: [:intermediate], to: [:output]
  end
end

# Expands to something like:
def execute(payload, context) do
  execution_plan = [
    %{id: :step_a, capability: :step_a, inputs: [:input], outputs: [:intermediate]},
    %{id: :step_b, capability: :step_b, inputs: [:intermediate], outputs: [:output]}
  ]
  
  PacketFlow.CompositionEngine.execute_pipeline(execution_plan, payload, context)
end
```

### Context Flow Management

The composition system automatically manages data flow:

```elixir
# Context structure during composition execution:
%{
  # Original context
  user_id: "123",
  session_id: "sess_abc", 
  trace_id: "trace_xyz",
  
  # Composition execution state
  composition: %{
    type: :pipeline,
    current_step: :step_b,
    step_results: %{
      step_a: %{intermediate: "value_from_step_a"},
      # step_b: ... (in progress)
    },
    execution_metadata: %{
      started_at: ~U[2025-07-31 10:00:00Z],
      steps_completed: 1,
      total_steps: 2
    }
  }
}
```

### Error Handling Strategy

Different composition types handle errors differently:

- **Pipeline**: Stops on first error, rolls back if configured
- **Parallel**: Can continue with partial failures or fail fast
- **Conditional**: Error handling per branch
- **Event-driven**: State-specific error handling
- **Loop**: Can skip failed iterations or break
- **Retry**: Automatic retry with fallback
- **Map-reduce**: Failed map tasks can be retried

### Observability Integration

All composition macros automatically:

- **Generate telemetry events** for each step
- **Propagate trace context** through all steps
- **Log execution flow** with structured data
- **Emit metrics** for composition performance
- **Create execution graphs** for visualization

## Usage Examples

### Simple Sequential Flow
```elixir
capability :user_registration do
  requires [:email, :password]
  provides [:user_account]
  
  pipeline do
    step :validate_input
    step :create_account  
    step :send_confirmation
  end
end
```

### Complex Business Process
```elixir
capability :loan_application_processing do
  requires [:application_data]
  provides [:decision, :loan_terms]
  
  pipeline do
    step :initial_validation
    
    parallel do
      branch :credit_check
      branch :income_verification
      branch :collateral_assessment
    end
    
    conditional do
      when all_checks_passed?() do
        sequence do
          step :calculate_risk_score
          step :determine_loan_terms
          step :generate_approval
        end
      end
      
      otherwise do
        step :generate_rejection
      end
    end
  end
end
```

This composition system provides the expressiveness needed for complex distributed workflows while maintaining PacketFlow's core principles of observability, error handling, and distributed execution.
