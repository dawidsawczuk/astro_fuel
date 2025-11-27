defmodule AstroFuel.Mission do
  @moduledoc """
  Represents a complete mission: spacecraft mass and an ordered flight path.

  The mission struct holds the input state for fuel calculation. Use
  `calculate/1` to compute fuel requirements, which returns a result map
  with per-step breakdown and validation status.

  ## Fields

    - `:mass` - Spacecraft dry mass in kg (non-negative integer)
    - `:steps` - List of `%FlightStep{}` in chronological order

  ## Constraints

    - Mass must be between 0 and 1,000,000 kg for valid calculations
    - Flight path must contain at least one step

  ## Examples

      iex> mission = AstroFuel.Mission.new(28_801)
      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
      iex> mission = AstroFuel.Mission.add_step(mission, step)
      iex> result = AstroFuel.Mission.calculate(mission)
      iex> result.valid?
      true
      iex> result.total_fuel > 0
      true
  """

  alias AstroFuel.{FlightStep, Fuel}

  @type t :: %__MODULE__{
          mass: non_neg_integer(),
          steps: [FlightStep.t()]
        }

  @enforce_keys [:mass, :steps]
  defstruct mass: 0, steps: []

  @max_mass 1_000_000
  @mass_error "Mass must be positive"
  @mass_upper_error "Mass exceeds supported limits"
  @path_error "Flight path is empty"

  @type calculation_result :: %{
          total_fuel: non_neg_integer(),
          step_details: [Fuel.step_detail()],
          valid?: boolean(),
          errors: [String.t()]
        }

  @doc """
  Creates a new mission with the given mass and empty flight path.

  ## Parameters

    - `mass` - Spacecraft dry mass in kg (non-negative integer)

  ## Examples

      iex> mission = AstroFuel.Mission.new(28_801)
      iex> mission.mass
      28_801

      iex> mission = AstroFuel.Mission.new(0)
      iex> mission.mass
      0

      iex> AstroFuel.Mission.new(-1)
      ** (ArgumentError) Invalid mass -1. Provide a value between 0 and #{@max_mass} kg.
  """
  @spec new(non_neg_integer()) :: t()
  def new(mass) when is_integer(mass) and mass >= 0 and mass <= @max_mass do
    %__MODULE__{mass: mass, steps: []}
  end

  def new(mass) when is_integer(mass) do
    raise ArgumentError, "Invalid mass #{mass}. Provide a value between 0 and #{@max_mass} kg."
  end

  def new(mass) do
    raise ArgumentError,
          "Invalid mass #{inspect(mass)}. Provide a value between 0 and #{@max_mass} kg."
  end

  @doc """
  Adds a step to the end of the mission's flight path.

  ## Parameters

    - `mission` - The mission to update
    - `step` - A `%FlightStep{}` to append

  ## Examples

      iex> mission = AstroFuel.Mission.new(1_000)
      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
      iex> mission = AstroFuel.Mission.add_step(mission, step)
      iex> length(mission.steps)
      1
  """
  @spec add_step(t(), FlightStep.t()) :: t()
  def add_step(%__MODULE__{steps: steps} = mission, %FlightStep{} = step) do
    %{mission | steps: steps ++ [step]}
  end

  @doc """
  Removes a step by its ID.

  If no step with the given ID exists, returns the mission unchanged.

  ## Parameters

    - `mission` - The mission to update
    - `step_id` - The ID of the step to remove

  ## Examples

      iex> mission = AstroFuel.Mission.new(1_000)
      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth, id: "remove_me")
      iex> mission = AstroFuel.Mission.add_step(mission, step)
      iex> mission = AstroFuel.Mission.remove_step(mission, "remove_me")
      iex> length(mission.steps)
      0
  """
  @spec remove_step(t(), String.t()) :: t()
  def remove_step(%__MODULE__{steps: steps} = mission, step_id) when is_binary(step_id) do
    %{mission | steps: Enum.reject(steps, &(&1.id == step_id))}
  end

  @doc """
  Moves a step from one index to another (0-indexed).

  If either index is out of bounds, returns the mission unchanged.

  ## Parameters

    - `mission` - The mission to update
    - `from_idx` - Current index of the step (0-indexed)
    - `to_idx` - Target index (0-indexed)

  ## Examples

      iex> mission = AstroFuel.Mission.new(1000)
      iex> {:ok, s1} = AstroFuel.FlightStep.new(:launch, :earth, id: "1")
      iex> {:ok, s2} = AstroFuel.FlightStep.new(:land, :moon, id: "2")
      iex> {:ok, s3} = AstroFuel.FlightStep.new(:launch, :moon, id: "3")
      iex> mission = mission |> AstroFuel.Mission.add_step(s1) |> AstroFuel.Mission.add_step(s2) |> AstroFuel.Mission.add_step(s3)
      iex> mission = AstroFuel.Mission.move_step(mission, 2, 0)
      iex> Enum.map(mission.steps, & &1.id)
      ["3", "1", "2"]
  """
  @spec move_step(t(), non_neg_integer(), non_neg_integer()) :: t()
  def move_step(%__MODULE__{steps: steps} = mission, from_idx, to_idx)
      when is_integer(from_idx) and is_integer(to_idx) and from_idx >= 0 and to_idx >= 0 do
    if from_idx >= length(steps) do
      mission
    else
      step = Enum.at(steps, from_idx)
      without = List.delete_at(steps, from_idx)
      target = clamp_index(to_idx, length(without))
      %{mission | steps: List.insert_at(without, target, step)}
    end
  end

  def move_step(mission, _from_idx, _to_idx), do: mission

  @doc """
  Updates a step by ID, replacing action and/or planet.

  ## Parameters

    - `mission` - The mission to update
    - `step_id` - The ID of the step to update
    - `attrs` - Keyword list of attributes to update:
      - `:action` - New action (`:launch` or `:land`)
      - `:planet` - New planet (`:earth`, `:moon`, `:mars`)

  ## Returns

    - `{:ok, updated_mission}` on success
    - `{:error, :step_not_found}` if no step with that ID exists
    - `{:error, :invalid_action}` if action is invalid
    - `{:error, :unknown_planet}` if planet is invalid

  ## Examples

      iex> mission = AstroFuel.Mission.new(1000)
      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth, id: "1")
      iex> mission = AstroFuel.Mission.add_step(mission, step)
      iex> {:ok, mission} = AstroFuel.Mission.update_step(mission, "1", action: :land, planet: :moon)
      iex> hd(mission.steps).action
      :land
      iex> hd(mission.steps).planet
      :moon

      iex> mission = AstroFuel.Mission.new(1000)
      iex> AstroFuel.Mission.update_step(mission, "nonexistent", action: :land)
      {:error, :step_not_found}
  """
  @spec update_step(t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, :step_not_found | :invalid_action | :unknown_planet}
  def update_step(%__MODULE__{steps: steps} = mission, step_id, attrs)
      when is_binary(step_id) and is_list(attrs) do
    case Enum.find_index(steps, &(&1.id == step_id)) do
      nil ->
        {:error, :step_not_found}

      idx ->
        old_step = Enum.at(steps, idx)
        action = Keyword.get(attrs, :action, old_step.action)
        planet = Keyword.get(attrs, :planet, old_step.planet)

        case FlightStep.new(action, planet, id: step_id) do
          {:ok, new_step} ->
            {:ok, %{mission | steps: List.replace_at(steps, idx, new_step)}}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Updates the spacecraft mass.

  ## Parameters

    - `mission` - The mission to update
    - `mass` - New mass in kg (non-negative integer)

  ## Examples

      iex> mission = AstroFuel.Mission.new(1000)
      iex> mission = AstroFuel.Mission.update_mass(mission, 28801)
      iex> mission.mass
      28_801
  """
  @spec update_mass(t(), non_neg_integer()) :: t()
  def update_mass(%__MODULE__{} = mission, mass) when is_integer(mass) and mass >= 0 do
    case validate_mass(mass) do
      :ok -> %{mission | mass: mass}
      {:error, _} -> mission
    end
  end

  def update_mass(mission, _mass), do: mission

  @doc """
  Calculates fuel requirements for the entire mission.

  Fuel is calculated in **reverse order** of the flight path because
  each step's fuel adds to the mass that previous steps must lift.

  ## Parameters

    - `mission` - The mission to calculate fuel for

  ## Returns

  A result map with:

    - `:total_fuel` - Sum of fuel for all steps (integer, kg)
    - `:step_details` - List of `%{step: step, fuel: fuel}` in original order
    - `:valid?` - Whether the mission is calculable
    - `:errors` - List of validation error messages

  ## Examples

      iex> mission = AstroFuel.Mission.new(28_801)
      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
      iex> mission = AstroFuel.Mission.add_step(mission, step)
      iex> result = AstroFuel.Mission.calculate(mission)
      iex> result.valid?
      true
      iex> result.total_fuel
      19_772

      iex> mission = %AstroFuel.Mission{mass: 0, steps: []}
      iex> result = AstroFuel.Mission.calculate(mission)
      iex> result.valid?
      false
      iex> result.errors
      ["Mass must be positive", "Flight path is empty"]

      iex> mission = %AstroFuel.Mission{mass: 28_801, steps: []}
      iex> result = AstroFuel.Mission.calculate(mission)
      iex> result.errors
      ["Flight path is empty"]
  """
  @spec calculate(t()) :: calculation_result()
  def calculate(%__MODULE__{mass: mass, steps: steps}) do
    errors =
      []
      |> collect_error(validate_mass(mass))
      |> collect_error(validate_steps(steps))

    if errors == [] do
      {total, details} = Fuel.calculate_path(mass, steps)
      %{total_fuel: total, step_details: details, valid?: true, errors: []}
    else
      %{total_fuel: 0, step_details: [], valid?: false, errors: errors}
    end
  end

  @doc """
  Validates that a mass value can be used for fuel calculations.

  Returns `:ok` for positive integers, otherwise `{:error, msg}` with the
  same message surfaced by `calculate/1` and user interfaces.
  """
  @spec validate_mass(integer()) :: :ok | {:error, String.t()}
  def validate_mass(mass) when is_integer(mass) and mass > 0 and mass <= @max_mass, do: :ok

  def validate_mass(mass) when is_integer(mass) and mass > @max_mass,
    do: {:error, @mass_upper_error}

  def validate_mass(_mass), do: {:error, @mass_error}

  @doc false
  @spec validate_steps([FlightStep.t()]) :: :ok | {:error, String.t()}
  def validate_steps([]), do: {:error, @path_error}
  def validate_steps(_steps), do: :ok

  defp clamp_index(index, length) when index > length, do: length
  defp clamp_index(index, _length), do: index

  defp collect_error(list, :ok), do: list
  defp collect_error(list, {:error, message}), do: list ++ [message]
end
