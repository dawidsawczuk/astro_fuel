defmodule AstroFuel.PhysicsTest do
  use ExUnit.Case, async: true
  doctest AstroFuel.Physics

  alias AstroFuel.Physics

  describe "gravity/1" do
    test "returns correct gravity for Earth" do
      assert {:ok, 9.807} = Physics.gravity(:earth)
    end

    test "returns correct gravity for Moon" do
      assert {:ok, 1.62} = Physics.gravity(:moon)
    end

    test "returns correct gravity for Mars" do
      assert {:ok, 3.711} = Physics.gravity(:mars)
    end

    test "returns error for unknown planet" do
      assert {:error, :unknown_planet} = Physics.gravity(:pluto)
      assert {:error, :unknown_planet} = Physics.gravity(:jupiter)
      assert {:error, :unknown_planet} = Physics.gravity("earth")
    end
  end

  describe "planets/0" do
    test "returns list of supported planets" do
      planets = Physics.planets()
      assert :earth in planets
      assert :moon in planets
      assert :mars in planets
      assert length(planets) == 3
    end
  end

  describe "valid_planet?/1" do
    test "returns true for supported planets" do
      assert Physics.valid_planet?(:earth)
      assert Physics.valid_planet?(:moon)
      assert Physics.valid_planet?(:mars)
    end

    test "returns false for unsupported planets" do
      refute Physics.valid_planet?(:pluto)
      refute Physics.valid_planet?(:venus)
      refute Physics.valid_planet?("earth")
    end
  end
end
