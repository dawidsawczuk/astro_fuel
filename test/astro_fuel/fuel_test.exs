defmodule AstroFuel.FuelTest do
  use ExUnit.Case, async: true
  doctest AstroFuel.Fuel

  alias AstroFuel.{FlightStep, Fuel}

  describe "calculate_step/3 - single maneuver" do
    test "launch from Earth with known mass returns correct fuel" do
      # Calculated: 28_801 kg launching from Earth
      assert {:ok, 19_772} = Fuel.calculate_step(:launch, :earth, 28_801)
    end

    test "land on Moon returns correct fuel" do
      assert {:ok, 1_535} = Fuel.calculate_step(:land, :moon, 28_801)
    end

    test "land on Mars returns correct fuel" do
      assert {:ok, 3_874} = Fuel.calculate_step(:land, :mars, 28_801)
    end

    test "launch from Moon returns correct fuel" do
      assert {:ok, 2_024} = Fuel.calculate_step(:launch, :moon, 28_801)
    end

    test "land on Earth returns correct fuel" do
      # Landing on Earth requires significant fuel due to high gravity
      assert {:ok, 13_447} = Fuel.calculate_step(:land, :earth, 28_801)
    end

    test "zero mass returns zero fuel" do
      assert {:ok, 0} = Fuel.calculate_step(:launch, :earth, 0)
    end

    test "negative mass returns zero fuel" do
      assert {:ok, 0} = Fuel.calculate_step(:land, :mars, -1_000)
    end

    test "very small mass may return zero fuel" do
      # For very small masses, base formula may already be negative
      assert {:ok, fuel} = Fuel.calculate_step(:launch, :moon, 100)
      assert fuel >= 0
    end

    test "returns error for unknown planet" do
      assert {:error, :unknown_planet} = Fuel.calculate_step(:launch, :pluto, 1_000)
      assert {:error, :unknown_planet} = Fuel.calculate_step(:land, :jupiter, 1_000)
    end

    test "large mass still works (no stack overflow)" do
      assert {:ok, fuel} = Fuel.calculate_step(:launch, :earth, 1_000_000)
      assert fuel > 0
    end
  end

  describe "calculate_path/2 - full mission" do
    test "Apollo 11 style mission: Earth → Moon → Earth" do
      # From assignment: spacecraft mass 28_801
      # Launch Earth, Land Moon, Launch Moon, Land Earth
      steps =
        build_steps([
          {:launch, :earth},
          {:land, :moon},
          {:launch, :moon},
          {:land, :earth}
        ])

      {total, details} = Fuel.calculate_path(28_801, steps)

      # Expected: 51_898 kg total fuel
      assert total == 51_898
      assert length(details) == 4
    end

    test "Mars mission" do
      # From assignment: spacecraft mass 14_606
      # Launch Earth, Land Mars, Launch Mars, Land Earth
      steps =
        build_steps([
          {:launch, :earth},
          {:land, :mars},
          {:launch, :mars},
          {:land, :earth}
        ])

      {total, _details} = Fuel.calculate_path(14_606, steps)

      # Expected: 33_388 kg total fuel
      assert total == 33_388
    end

    test "preserves step order in details" do
      steps =
        build_steps([
          {:launch, :earth},
          {:land, :moon},
          {:launch, :moon}
        ])

      {_total, details} = Fuel.calculate_path(10_000, steps)

      ids = Enum.map(details, fn %{step: s} -> s.id end)
      assert ids == ["step_0", "step_1", "step_2"]
    end

    test "each step has fuel value" do
      steps = build_steps([{:launch, :earth}, {:land, :mars}])
      {_total, details} = Fuel.calculate_path(28_801, steps)

      Enum.each(details, fn %{step: _, fuel: fuel} ->
        assert is_integer(fuel)
        assert fuel >= 0
      end)
    end

    test "empty path returns zero" do
      assert {0, []} = Fuel.calculate_path(28_801, [])
    end

    test "zero mass returns zero" do
      steps = build_steps([{:launch, :earth}])
      assert {0, []} = Fuel.calculate_path(0, steps)
    end

    test "single step works" do
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      {total, details} = Fuel.calculate_path(28_801, [step])

      assert total == 19_772
      assert length(details) == 1
      assert hd(details).fuel == 19_772
    end

    test "step order affects total fuel" do
      # Same steps, different order = different fuel requirements
      # because fuel for later steps must be carried by earlier steps
      steps_a = build_steps([{:launch, :earth}, {:land, :mars}])
      steps_b = build_steps([{:land, :mars}, {:launch, :earth}])

      {fuel_a, _} = Fuel.calculate_path(10_000, steps_a)
      {fuel_b, _} = Fuel.calculate_path(10_000, steps_b)

      # Launch requires more fuel, so launching first with extra landing fuel
      # is different from landing first with launch fuel
      assert fuel_a != fuel_b
    end

    test "fuel compounds - earlier steps carry later steps' fuel" do
      {:ok, step1} = FlightStep.new(:launch, :earth, id: "1")
      {:ok, step2} = FlightStep.new(:land, :moon, id: "2")

      # Single launch from Earth
      {single_launch, _} = Fuel.calculate_path(28_801, [step1])

      # Launch + land: launch must carry landing fuel too
      {_both, details} = Fuel.calculate_path(28_801, [step1, step2])

      # The launch fuel when followed by land should be MORE than launch alone
      launch_detail = Enum.find(details, &(&1.step.id == "1"))
      assert launch_detail.fuel > single_launch
    end
  end

  describe "fuel monotonicity properties" do
    test "fuel increases with mass for launch" do
      masses = [1_000, 5_000, 10_000, 50_000, 100_000]

      fuels =
        Enum.map(masses, fn m ->
          {:ok, f} = Fuel.calculate_step(:launch, :earth, m)
          f
        end)

      # Each fuel should be greater than the previous (strictly increasing)
      pairs = Enum.zip(fuels, tl(fuels))
      assert Enum.all?(pairs, fn {a, b} -> b > a end)
    end

    test "fuel increases with mass for landing" do
      masses = [1_000, 5_000, 10_000, 50_000, 100_000]

      fuels =
        Enum.map(masses, fn m ->
          {:ok, f} = Fuel.calculate_step(:land, :mars, m)
          f
        end)

      pairs = Enum.zip(fuels, tl(fuels))
      assert Enum.all?(pairs, fn {a, b} -> b > a end)
    end

    test "launch requires more fuel than landing for same mass and planet" do
      # Launch overcomes gravity; landing uses gravity assist
      # So launch coefficient (0.042) > land coefficient (0.033)
      {:ok, launch_fuel} = Fuel.calculate_step(:launch, :earth, 28_801)
      {:ok, land_fuel} = Fuel.calculate_step(:land, :earth, 28_801)

      assert launch_fuel > land_fuel
    end
  end

  # Helper to build steps with sequential IDs
  defp build_steps(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {{action, planet}, idx} ->
      {:ok, step} = FlightStep.new(action, planet, id: "step_#{idx}")
      step
    end)
  end
end
