defmodule AstroFuel.Physics do
  @moduledoc """
  Physical constants and planet gravity lookup.

  Provides a controlled vocabulary of supported celestial bodies
  and their surface gravities in m/s².

  ## Supported Planets

    - `:earth` - 9.807 m/s²
    - `:moon` - 1.62 m/s²
    - `:mars` - 3.711 m/s²

  ## Examples

      iex> AstroFuel.Physics.gravity(:earth)
      {:ok, 9.807}

      iex> AstroFuel.Physics.gravity(:pluto)
      {:error, :unknown_planet}

      iex> AstroFuel.Physics.planets()
      [:earth, :moon, :mars]
  """

  @type planet :: :earth | :moon | :mars

  @gravities %{
    earth: 9.807,
    moon: 1.62,
    mars: 3.711
  }

  @planets Map.keys(@gravities)

  @doc """
  Returns the gravity (m/s²) for the given planet.

  ## Parameters

    - `planet` - A planet atom (`:earth`, `:moon`, or `:mars`)

  ## Returns

    - `{:ok, gravity}` where gravity is a float in m/s²
    - `{:error, :unknown_planet}` if planet is not supported

  ## Examples

      iex> AstroFuel.Physics.gravity(:earth)
      {:ok, 9.807}

      iex> AstroFuel.Physics.gravity(:moon)
      {:ok, 1.62}

      iex> AstroFuel.Physics.gravity(:mars)
      {:ok, 3.711}

      iex> AstroFuel.Physics.gravity(:pluto)
      {:error, :unknown_planet}
  """
  @spec gravity(planet()) :: {:ok, float()} | {:error, :unknown_planet}
  def gravity(planet) when planet in @planets, do: {:ok, @gravities[planet]}
  def gravity(_), do: {:error, :unknown_planet}

  @doc """
  Returns the list of supported planets.

  ## Examples

      iex> AstroFuel.Physics.planets()
      [:earth, :moon, :mars]
  """
  @spec planets() :: [planet()]
  def planets, do: @planets

  @doc """
  Checks if a planet is supported.

  ## Examples

      iex> AstroFuel.Physics.valid_planet?(:earth)
      true

      iex> AstroFuel.Physics.valid_planet?(:pluto)
      false
  """
  @spec valid_planet?(atom()) :: boolean()
  def valid_planet?(planet), do: planet in @planets
end
