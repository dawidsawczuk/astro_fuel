defmodule AstroFuel.FlightStep do
  @moduledoc """
  Represents a single step in a flight path: an action on a planet.

  A flight step is either a `:launch` from or `:land` on a supported planet.
  Each step is immutable and validated at construction time.

  ## Fields

    - `:id` - Unique identifier (string)
    - `:action` - Either `:launch` or `:land`
    - `:planet` - A supported planet (`:earth`, `:moon`, `:mars`)

  ## Examples

      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
      iex> step.action
      :launch
      iex> step.planet
      :earth

      iex> AstroFuel.FlightStep.new(:hover, :earth)
      {:error, :invalid_action}

      iex> AstroFuel.FlightStep.new(:launch, :pluto)
      {:error, :unknown_planet}
  """

  alias AstroFuel.Physics

  @type action :: :launch | :land

  @type t :: %__MODULE__{
          id: String.t(),
          action: action(),
          planet: Physics.planet()
        }

  @enforce_keys [:id, :action, :planet]
  defstruct [:id, :action, :planet]

  @actions [:launch, :land]

  @doc """
  Creates a new FlightStep with validation.

  ## Parameters

    - `action` - `:launch` or `:land`
    - `planet` - A supported planet atom (`:earth`, `:moon`, `:mars`)
    - `opts` - Optional keyword list:
      - `:id` - Custom ID (string); if not provided, one is generated

  ## Returns

    - `{:ok, %FlightStep{}}` on success
    - `{:error, :invalid_action}` if action is not `:launch` or `:land`
    - `{:error, :unknown_planet}` if planet is not supported

  ## Examples

      iex> {:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
      iex> step.action
      :launch

      iex> {:ok, step} = AstroFuel.FlightStep.new(:land, :moon, id: "step_1")
      iex> step.id
      "step_1"

      iex> AstroFuel.FlightStep.new(:hover, :earth)
      {:error, :invalid_action}

      iex> AstroFuel.FlightStep.new(:launch, :saturn)
      {:error, :unknown_planet}
  """
  @spec new(action(), Physics.planet(), keyword()) ::
          {:ok, t()} | {:error, :invalid_action | :unknown_planet}
  def new(action, planet, opts \\ [])

  def new(action, _planet, _opts) when action not in @actions do
    {:error, :invalid_action}
  end

  def new(action, planet, opts) do
    case Physics.gravity(planet) do
      {:ok, _} ->
        id = Keyword.get(opts, :id, generate_id())
        {:ok, %__MODULE__{id: id, action: action, planet: planet}}

      {:error, :unknown_planet} = error ->
        error
    end
  end

  @doc """
  Returns the list of valid actions.

  ## Examples

      iex> AstroFuel.FlightStep.actions()
      [:launch, :land]
  """
  @spec actions() :: [action()]
  def actions, do: @actions

  @doc """
  Checks if an action is valid.

  ## Examples

      iex> AstroFuel.FlightStep.valid_action?(:launch)
      true

      iex> AstroFuel.FlightStep.valid_action?(:hover)
      false
  """
  @spec valid_action?(atom()) :: boolean()
  def valid_action?(action), do: action in @actions

  # Generates a cryptographically secure random ID
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
