defmodule AstroFuel.MissionTest do
  use ExUnit.Case, async: true
  doctest AstroFuel.Mission

  alias AstroFuel.{FlightStep, Mission}

  describe "new/1" do
    test "creates mission with given mass" do
      mission = Mission.new(28_801)
      assert mission.mass == 28_801
      assert mission.steps == []
    end

    test "creates mission with zero mass" do
      mission = Mission.new(0)
      assert mission.mass == 0
    end

    test "raises on negative mass" do
      assert_raise ArgumentError, fn -> Mission.new(-100) end
    end

    test "raises on mass above supported range" do
      assert_raise ArgumentError, fn -> Mission.new(2_000_000) end
    end
  end

  describe "add_step/2" do
    test "appends step to empty mission" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth)

      updated = Mission.add_step(mission, step)

      assert length(updated.steps) == 1
      assert hd(updated.steps).action == :launch
    end

    test "appends step to end of existing steps" do
      mission = Mission.new(1_000)
      {:ok, step1} = FlightStep.new(:launch, :earth, id: "1")
      {:ok, step2} = FlightStep.new(:land, :moon, id: "2")

      updated = mission |> Mission.add_step(step1) |> Mission.add_step(step2)

      assert length(updated.steps) == 2
      assert Enum.map(updated.steps, & &1.id) == ["1", "2"]
    end

    test "does not modify original mission (immutability)" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth)

      _updated = Mission.add_step(mission, step)

      assert mission.steps == []
    end
  end

  describe "remove_step/2" do
    test "removes step by ID" do
      mission = Mission.new(1_000)
      {:ok, step1} = FlightStep.new(:launch, :earth, id: "keep")
      {:ok, step2} = FlightStep.new(:land, :moon, id: "remove")

      mission = mission |> Mission.add_step(step1) |> Mission.add_step(step2)
      updated = Mission.remove_step(mission, "remove")

      assert length(updated.steps) == 1
      assert hd(updated.steps).id == "keep"
    end

    test "returns unchanged mission if ID not found" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "exists")

      mission = Mission.add_step(mission, step)
      updated = Mission.remove_step(mission, "nonexistent")

      assert updated.steps == mission.steps
    end

    test "works on empty mission" do
      mission = Mission.new(1_000)
      updated = Mission.remove_step(mission, "any_id")

      assert updated.steps == []
    end
  end

  describe "move_step/3" do
    setup do
      mission = Mission.new(1_000)
      {:ok, s1} = FlightStep.new(:launch, :earth, id: "1")
      {:ok, s2} = FlightStep.new(:land, :moon, id: "2")
      {:ok, s3} = FlightStep.new(:launch, :moon, id: "3")

      mission =
        mission
        |> Mission.add_step(s1)
        |> Mission.add_step(s2)
        |> Mission.add_step(s3)

      {:ok, mission: mission}
    end

    test "moves step from end to beginning", %{mission: mission} do
      moved = Mission.move_step(mission, 2, 0)
      assert Enum.map(moved.steps, & &1.id) == ["3", "1", "2"]
    end

    test "moves step from beginning to end", %{mission: mission} do
      moved = Mission.move_step(mission, 0, 2)
      assert Enum.map(moved.steps, & &1.id) == ["2", "3", "1"]
    end

    test "moves step to middle", %{mission: mission} do
      moved = Mission.move_step(mission, 0, 1)
      assert Enum.map(moved.steps, & &1.id) == ["2", "1", "3"]
    end

    test "returns unchanged if from index out of bounds", %{mission: mission} do
      moved = Mission.move_step(mission, 10, 0)
      assert Enum.map(moved.steps, & &1.id) == ["1", "2", "3"]
    end

    test "clamps target index beyond list length", %{mission: mission} do
      moved = Mission.move_step(mission, 0, 99)
      assert Enum.map(moved.steps, & &1.id) == ["2", "3", "1"]
    end

    test "handles negative indices gracefully" do
      mission = Mission.new(1_000)
      moved = Mission.move_step(mission, -1, 0)
      assert moved.steps == []
    end
  end

  describe "update_step/3" do
    test "updates action" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      {:ok, updated} = Mission.update_step(mission, "1", action: :land)

      assert hd(updated.steps).action == :land
      assert hd(updated.steps).planet == :earth
      assert hd(updated.steps).id == "1"
    end

    test "updates planet" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      {:ok, updated} = Mission.update_step(mission, "1", planet: :mars)

      assert hd(updated.steps).action == :launch
      assert hd(updated.steps).planet == :mars
    end

    test "updates both action and planet" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      {:ok, updated} = Mission.update_step(mission, "1", action: :land, planet: :moon)

      assert hd(updated.steps).action == :land
      assert hd(updated.steps).planet == :moon
    end

    test "returns error for nonexistent step" do
      mission = Mission.new(1_000)

      assert {:error, :step_not_found} =
               Mission.update_step(mission, "nonexistent", action: :land)
    end

    test "returns error for invalid action" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      assert {:error, :invalid_action} = Mission.update_step(mission, "1", action: :hover)
    end

    test "returns error for invalid planet" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      assert {:error, :unknown_planet} = Mission.update_step(mission, "1", planet: :pluto)
    end
  end

  describe "update_mass/2" do
    test "updates mass" do
      mission = Mission.new(1_000)
      updated = Mission.update_mass(mission, 28_801)
      assert updated.mass == 28_801
    end

    test "preserves steps" do
      mission = Mission.new(1_000)
      {:ok, step} = FlightStep.new(:launch, :earth, id: "1")
      mission = Mission.add_step(mission, step)

      updated = Mission.update_mass(mission, 28_801)

      assert length(updated.steps) == 1
      assert hd(updated.steps).id == "1"
    end

    test "handles invalid mass gracefully" do
      mission = Mission.new(1_000)
      updated = Mission.update_mass(mission, -100)
      assert updated.mass == 1_000
    end

    test "ignores mass updates above supported range" do
      mission = Mission.new(1_000)
      updated = Mission.update_mass(mission, 2_000_000)
      assert updated.mass == 1_000
    end
  end

  describe "calculate/1" do
    test "returns valid result for complete mission" do
      mission = Mission.new(28_801)
      {:ok, step} = FlightStep.new(:launch, :earth)
      mission = Mission.add_step(mission, step)

      result = Mission.calculate(mission)

      assert result.valid?
      assert result.total_fuel == 19_772
      assert length(result.step_details) == 1
      assert result.errors == []
    end

    test "returns invalid result when mass is zero" do
      mission = Mission.new(0)
      {:ok, step} = FlightStep.new(:launch, :earth)
      mission = Mission.add_step(mission, step)

      result = Mission.calculate(mission)

      refute result.valid?
      assert result.total_fuel == 0
      assert "Mass must be positive" in result.errors
    end

    test "returns invalid result when path is empty" do
      mission = Mission.new(28_801)

      result = Mission.calculate(mission)

      refute result.valid?
      assert result.total_fuel == 0
      assert "Flight path is empty" in result.errors
    end

    test "returns both errors when mass invalid and path empty" do
      mission = %Mission{mass: 0, steps: []}
      result = Mission.calculate(mission)

      refute result.valid?
      assert result.errors == ["Mass must be positive", "Flight path is empty"]
    end

    test "calculates Apollo 11 mission correctly" do
      mission = Mission.new(28_801)

      steps = [
        {:launch, :earth},
        {:land, :moon},
        {:launch, :moon},
        {:land, :earth}
      ]

      mission =
        Enum.reduce(steps, mission, fn {action, planet}, acc ->
          {:ok, step} = FlightStep.new(action, planet)
          Mission.add_step(acc, step)
        end)

      result = Mission.calculate(mission)

      assert result.valid?
      assert result.total_fuel == 51_898
      assert length(result.step_details) == 4
    end

    test "calculates Mars mission correctly" do
      mission = Mission.new(14_606)

      steps = [
        {:launch, :earth},
        {:land, :mars},
        {:launch, :mars},
        {:land, :earth}
      ]

      mission =
        Enum.reduce(steps, mission, fn {action, planet}, acc ->
          {:ok, step} = FlightStep.new(action, planet)
          Mission.add_step(acc, step)
        end)

      result = Mission.calculate(mission)

      assert result.valid?
      assert result.total_fuel == 33_388
    end

    test "step_details match step order" do
      mission = Mission.new(10_000)
      {:ok, s1} = FlightStep.new(:launch, :earth, id: "first")
      {:ok, s2} = FlightStep.new(:land, :moon, id: "second")

      mission = mission |> Mission.add_step(s1) |> Mission.add_step(s2)

      result = Mission.calculate(mission)

      ids = Enum.map(result.step_details, fn %{step: s} -> s.id end)
      assert ids == ["first", "second"]
    end
  end

  describe "validate_mass/1" do
    test "accepts positive integers up to max" do
      assert :ok = Mission.validate_mass(1)
      assert :ok = Mission.validate_mass(1_000_000)
    end

    test "rejects zero or negative values" do
      assert {:error, "Mass must be positive"} = Mission.validate_mass(0)
      assert {:error, "Mass must be positive"} = Mission.validate_mass(-5)
    end

    test "rejects masses above max" do
      assert {:error, "Mass exceeds supported limits"} = Mission.validate_mass(1_000_001)
    end
  end
end
