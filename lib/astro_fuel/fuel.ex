defmodule AstroFuel.Fuel do
  @moduledoc """
  Pure fuel calculation functions for spacecraft missions.

  All functions are pure and side-effect free. Mass is in kilograms,
  fuel output is in kilograms (rounded down to integer).

  ## Formulas

    - **Launch:** `floor(mass × gravity × 0.042 − 33)`
    - **Landing:** `floor(mass × gravity × 0.033 − 42)`

  ## Recursive Calculation

  Fuel is calculated recursively: the fuel itself has mass, which requires
  additional fuel to carry. The calculation repeats until the additional
  fuel needed is zero or negative, then all positive fuel values are summed.

  ## Path Calculation

  When calculating fuel for a multi-step flight path, steps are processed
  in **reverse order** because fuel for later steps must be carried during
  earlier steps, increasing their mass requirements.

  ## Examples

      # Single step
      iex> AstroFuel.Fuel.calculate_step(:launch, :earth, 28_801)
      {:ok, 19_772}

      # Full path with multiple steps
      iex> {:ok, s1} = AstroFuel.FlightStep.new(:launch, :earth, id: "1")
      iex> {:ok, s2} = AstroFuel.FlightStep.new(:land, :moon, id: "2")
      iex> {total, _details} = AstroFuel.Fuel.calculate_path(28_801, [s1, s2])
      iex> total
      22_380
  """

  alias AstroFuel.{FlightStep, Physics}

  @launch_coeff 0.042
  @launch_const 33
  @land_coeff 0.033
  @land_const 42

  @type step_detail :: %{step: FlightStep.t(), fuel: non_neg_integer()}

  @doc """
  Calculates total fuel for a single maneuver, including fuel for the fuel.

  The calculation is recursive: each iteration computes the fuel needed for
  the current mass, then uses that fuel amount as the new mass until the
  additional fuel required is zero or negative.

  ## Parameters

    - `action` - `:launch` or `:land`
    - `planet` - A supported planet (`:earth`, `:moon`, `:mars`)
    - `mass` - Total mass in kg to be moved (must be positive for non-zero result)

  ## Returns

    - `{:ok, fuel}` where `fuel` is a non-negative integer in kg
    - `{:error, :unknown_planet}` if planet is not supported

  ## Examples

      iex> AstroFuel.Fuel.calculate_step(:launch, :earth, 28_801)
      {:ok, 19_772}

      iex> AstroFuel.Fuel.calculate_step(:land, :moon, 28_801)
      {:ok, 1_535}

      iex> AstroFuel.Fuel.calculate_step(:land, :mars, 28_801)
      {:ok, 3_874}

      iex> AstroFuel.Fuel.calculate_step(:launch, :moon, 28_801)
      {:ok, 2_024}

      iex> AstroFuel.Fuel.calculate_step(:launch, :earth, 0)
      {:ok, 0}

      iex> AstroFuel.Fuel.calculate_step(:launch, :pluto, 1000)
      {:error, :unknown_planet}
  """
  @spec calculate_step(FlightStep.action(), Physics.planet(), number()) ::
          {:ok, non_neg_integer()} | {:error, :unknown_planet}
  def calculate_step(_action, _planet, mass) when mass <= 0, do: {:ok, 0}

  def calculate_step(action, planet, mass) do
    with {:ok, gravity} <- Physics.gravity(planet) do
      {:ok, accumulate_fuel(action, gravity, mass, 0)}
    end
  end

  @doc """
  Calculates fuel for an entire flight path.

  Steps are processed in reverse chronological order because fuel for later
  steps must be carried during earlier steps, increasing their mass.

  ## Parameters

    - `spacecraft_mass` - Dry mass of spacecraft in kg (positive integer)
    - `steps` - List of `%FlightStep{}` structs in chronological order

  ## Returns

  A tuple `{total_fuel, step_details}` where:

    - `total_fuel` - Integer sum of fuel for all steps
    - `step_details` - List of `%{step: step, fuel: fuel}` in original chronological order

  ## Examples

      iex> {:ok, s1} = AstroFuel.FlightStep.new(:launch, :earth, id: "1")
      iex> {:ok, s2} = AstroFuel.FlightStep.new(:land, :moon, id: "2")
      iex> {:ok, s3} = AstroFuel.FlightStep.new(:launch, :moon, id: "3")
      iex> {:ok, s4} = AstroFuel.FlightStep.new(:land, :earth, id: "4")
      iex> {total, details} = AstroFuel.Fuel.calculate_path(28_801, [s1, s2, s3, s4])
      iex> total
      51_898
      iex> length(details)
      4

      iex> AstroFuel.Fuel.calculate_path(28_801, [])
      {0, []}

      iex> AstroFuel.Fuel.calculate_path(0, [])
      {0, []}
  """
  @spec calculate_path(non_neg_integer(), [FlightStep.t()]) ::
          {non_neg_integer(), [step_detail()]}
  def calculate_path(mass, steps) when is_integer(mass) and mass > 0 and is_list(steps) do
    # Process in reverse: fuel from later steps adds to mass for earlier steps
    {_final_mass, reversed_details} =
      steps
      |> Enum.reverse()
      |> Enum.reduce({mass, []}, fn step, {current_mass, acc} ->
        {:ok, fuel} = calculate_step(step.action, step.planet, current_mass)
        # New mass includes the fuel we need to carry
        {current_mass + fuel, [%{step: step, fuel: fuel} | acc]}
      end)

    # reversed_details is now in original order (we prepended while reversing)
    total = Enum.reduce(reversed_details, 0, fn %{fuel: f}, acc -> acc + f end)
    {total, reversed_details}
  end

  def calculate_path(_mass, _steps), do: {0, []}

  # --- Private Functions ---

  # Recursively accumulates fuel until additional fuel is <= 0
  @spec accumulate_fuel(FlightStep.action(), float(), number(), non_neg_integer()) ::
          non_neg_integer()
  defp accumulate_fuel(action, gravity, mass, acc) do
    fuel = base_fuel(action, gravity, mass)

    if fuel <= 0 do
      acc
    else
      accumulate_fuel(action, gravity, fuel, acc + fuel)
    end
  end

  # Base fuel formula (single iteration, not recursive)
  @spec base_fuel(FlightStep.action(), float(), number()) :: integer()
  defp base_fuel(:launch, gravity, mass) do
    floor(mass * gravity * @launch_coeff - @launch_const)
  end

  defp base_fuel(:land, gravity, mass) do
    floor(mass * gravity * @land_coeff - @land_const)
  end
end
