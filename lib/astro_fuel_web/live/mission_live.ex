defmodule AstroFuelWeb.MissionLive do
  @moduledoc """
  LiveView for building flight paths and calculating fuel requirements.

  Users can:
  - Enter spacecraft mass
  - Add, remove, and reorder flight steps
  - See real-time fuel calculations as they edit

  All computation is delegated to `AstroFuel.Mission`.
  """

  use AstroFuelWeb, :live_view

  alias AstroFuel.{FlightStep, Mission, Physics}

  @action_lookup FlightStep.actions() |> Map.new(&{Atom.to_string(&1), &1})
  @planet_lookup Physics.planets() |> Map.new(&{Atom.to_string(&1), &1})

  @impl true
  def mount(_params, _session, socket) do
    mission = Mission.new(0)

    socket =
      assign(socket,
        page_title: "Fuel Calculator",
        mission: mission,
        result: Mission.calculate(mission),
        mass_input: "",
        mass_error: nil,
        planets: Physics.planets(),
        actions: FlightStep.actions()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 py-8">
      <div class="container mx-auto px-4 max-w-3xl">
        <h1 class="text-4xl font-bold text-center mb-8">🚀 Interplanetary Fuel Calculator</h1>
        <.mass_input_card mass_input={@mass_input} mass_error={@mass_error} />
        <.flight_path_card
          steps={@mission.steps}
          planets={@planets}
          actions={@actions}
          result={@result}
        /> <.fuel_summary result={@result} />
      </div>
    </div>
    """
  end

  # --- Components ---

  defp mass_input_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-lg mb-6">
      <div class="card-body">
        <h2 class="card-title">Spacecraft Configuration</h2>

        <label class="form-control w-full max-w-xs">
          <div class="label"><span class="label-text font-semibold">Dry Mass (kg)</span></div>

          <input
            type="text"
            inputmode="numeric"
            placeholder="e.g., 28_801"
            class={["input input-bordered w-full", @mass_error && "input-error"]}
            value={@mass_input}
            phx-change="update_mass"
            phx-blur="update_mass"
            name="mass"
            phx-debounce="300"
          />
          <div :if={@mass_error} class="label">
            <span class="label-text-alt text-error">{@mass_error}</span>
          </div>
        </label>
      </div>
    </div>
    """
  end

  defp flight_path_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-lg mb-6">
      <div class="card-body">
        <h2 class="card-title mb-4">Flight Path</h2>

        <div :if={@steps == []} class="text-base-content/50 italic text-center py-8">
          Add steps to plan your mission trajectory.
        </div>

        <div class="space-y-3">
          <.step_row
            :for={{step, idx} <- Enum.with_index(@steps)}
            step={step}
            index={idx}
            total_steps={length(@steps)}
            planets={@planets}
            actions={@actions}
            fuel={step_fuel(@result, step.id)}
          />
        </div>

        <div class="mt-4">
          <button class="btn btn-primary" phx-click="add_step">
            <span class="text-lg mr-1">+</span> Add Step
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp step_row(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2 p-3 bg-base-200 rounded-lg">
      <span class="badge badge-lg badge-neutral font-mono">{@index + 1}</span>
      <form phx-change="update_step" phx-value-id={@step.id} class="contents">
        <select
          class="select select-bordered select-sm"
          name="action"
        >
          <option :for={action <- @actions} value={action} selected={action == @step.action}>
            {action |> Atom.to_string() |> String.capitalize()}
          </option>
        </select>
         <span class="text-sm font-medium">on</span>
        <select
          class="select select-bordered select-sm"
          name="planet"
        >
          <option :for={planet <- @planets} value={planet} selected={planet == @step.planet}>
            {planet |> Atom.to_string() |> String.capitalize()}
          </option>
        </select>
      </form>

      <div class="flex-1"></div>
      <span class="badge badge-accent badge-lg font-mono">{format_number(@fuel)} kg</span>
      <div class="join">
        <button
          :if={@index > 0}
          class="btn btn-ghost btn-xs join-item"
          phx-click="move_step"
          phx-value-from={@index}
          phx-value-to={@index - 1}
          title="Move up"
        >
          ↑
        </button>
        <button
          :if={@index < @total_steps - 1}
          class="btn btn-ghost btn-xs join-item"
          phx-click="move_step"
          phx-value-from={@index}
          phx-value-to={@index + 1}
          title="Move down"
        >
          ↓
        </button>
        <button
          class="btn btn-ghost btn-xs join-item text-error"
          phx-click="remove_step"
          phx-value-id={@step.id}
          title="Remove step"
        >
          ✕
        </button>
      </div>
    </div>
    """
  end

  defp fuel_summary(assigns) do
    ~H"""
    <div class={[
      "card shadow-lg",
      if(@result.valid?, do: "bg-success text-success-content", else: "bg-base-100")
    ]}>
      <div class="card-body">
        <h2 class="card-title">Mission Summary</h2>

        <div :if={not @result.valid?} class="py-4">
          <div :for={error <- @result.errors} class="flex items-center gap-2 text-warning">
            <span class="text-xl">⚠️</span> <span class="font-medium">{error}</span>
          </div>

          <div :if={@result.errors == []} class="text-base-content/50 italic">
            Configure your mission to see fuel requirements.
          </div>
        </div>

        <div :if={@result.valid?} class="py-4 space-y-4">
          <div class="stats stats-vertical lg:stats-horizontal bg-success-content/10 w-full">
            <div class="stat">
              <div class="stat-title text-success-content/70">Total Fuel Required</div>

              <div class="stat-value">{format_number(@result.total_fuel)} kg</div>
            </div>

            <div class="stat">
              <div class="stat-title text-success-content/70">Flight Steps</div>

              <div class="stat-value">{length(@result.step_details)}</div>
            </div>
          </div>

          <div :if={@result.total_fuel == 0} class="alert alert-info bg-base-100 text-base-content">
            <span class="font-medium">No fuel needed:</span>
            <span>
              For very light payloads the launch/landing formula floors to zero, so each step
              reports 0&nbsp;kg. Increase mass or adjust steps to see non-zero fuel requirements.
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("update_mass", params, socket) do
    mass_str = Map.get(params, "mass") || Map.get(params, "value")
    {:noreply, process_mass_input(socket, mass_str)}
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    case FlightStep.new(:launch, :earth) do
      {:ok, step} ->
        mission = Mission.add_step(socket.assigns.mission, step)
        {:noreply, recalculate(socket, mission)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_step", %{"id" => id}, socket) do
    mission = Mission.remove_step(socket.assigns.mission, id)
    {:noreply, recalculate(socket, mission)}
  end

  @impl true
  def handle_event("update_step", %{"id" => id} = params, socket) do
    attrs =
      []
      |> maybe_add_attr(params, "action")
      |> maybe_add_attr(params, "planet")

    case Mission.update_step(socket.assigns.mission, id, attrs) do
      {:ok, mission} ->
        {:noreply, recalculate(socket, mission)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, step_error_message(reason))}
    end
  end

  @impl true
  def handle_event("move_step", %{"from" => from, "to" => to}, socket) do
    with {:ok, from_idx} <- parse_index(from),
         {:ok, to_idx} <- parse_index(to) do
      mission = Mission.move_step(socket.assigns.mission, from_idx, to_idx)
      {:noreply, recalculate(socket, mission)}
    else
      _ -> {:noreply, socket}
    end
  end

  defp parse_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_index(_), do: :error

  defp lookup(_mapping, nil), do: :error

  defp lookup(mapping, value) when is_binary(value) do
    Map.fetch(mapping, value)
  end

  defp lookup(_mapping, _), do: :error

  # --- Private Helpers ---

  defp process_mass_input(socket, nil), do: process_mass_input(socket, "")

  defp process_mass_input(socket, value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        mission = %{socket.assigns.mission | mass: 0}
        socket |> assign(mass_input: "", mass_error: nil) |> recalculate(mission)

      trimmed ->
        parse_mass(socket, trimmed)
    end
  end

  defp parse_mass(socket, mass_str) do
    case Integer.parse(mass_str) do
      {mass, ""} ->
        case Mission.validate_mass(mass) do
          :ok ->
            mission = %{socket.assigns.mission | mass: mass}
            socket |> assign(mass_input: mass_str, mass_error: nil) |> recalculate(mission)

          {:error, message} ->
            assign(socket, mass_input: mass_str, mass_error: message)
        end

      _ ->
        assign(socket, mass_input: mass_str, mass_error: "Enter a valid integer")
    end
  end

  defp recalculate(socket, mission) do
    result = Mission.calculate(mission)
    assign(socket, mission: mission, result: result)
  end

  defp maybe_add_attr(attrs, params, "action") do
    case lookup(@action_lookup, Map.get(params, "action")) do
      {:ok, action} -> [{:action, action} | attrs]
      :error -> attrs
    end
  end

  defp maybe_add_attr(attrs, params, "planet") do
    case lookup(@planet_lookup, Map.get(params, "planet")) do
      {:ok, planet} -> [{:planet, planet} | attrs]
      :error -> attrs
    end
  end

  defp maybe_add_attr(attrs, _params, _field), do: attrs

  defp step_fuel(%{step_details: details}, id) do
    case Enum.find(details, &(&1.step.id == id)) do
      %{fuel: fuel} -> fuel
      _ -> 0
    end
  end

  defp step_fuel(_, _), do: 0

  defp step_error_message(:step_not_found), do: "Step no longer exists"
  defp step_error_message(:invalid_action), do: "Choose a valid action"
  defp step_error_message(:unknown_planet), do: "Choose a valid planet"

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_number(_), do: "0"
end
