# AstroFuel 🚀

Real-time interplanetary fuel calculator built with Phoenix LiveView.

## Features

- Calculate fuel requirements for multi-step space missions
- Support for Earth, Moon, and Mars gravity
- Recursive fuel calculation (fuel adds weight, requiring more fuel)
- Real-time updates as you build your flight path
- Add, remove, and reorder flight steps
- Per-step fuel breakdown and total calculation

## Quick Start

```bash
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) to use the calculator.

## Running Tests

```bash
mix test                    # All tests (44 doctests + 93 tests)
mix test test/astro_fuel/   # Domain logic only
```

## Architecture

### Domain Layer (`lib/astro_fuel/`)

Pure Elixir modules with no Phoenix dependencies:

| Module | Responsibility |
|--------|----------------|
| `Physics` | Gravity constants for Earth, Moon, Mars |
| `FlightStep` | Step struct and validation (action + planet) |
| `Fuel` | Core fuel calculation with recursive algorithm |
| `Mission` | Mission composition and calculation orchestration |

### Web Layer (`lib/astro_fuel_web/`)

| Module | Responsibility |
|--------|----------------|
| `MissionLive` | LiveView for interactive mission planning |

## Fuel Formulas

- **Launch:** `floor(mass × gravity × 0.042 − 33)`
- **Landing:** `floor(mass × gravity × 0.033 − 42)`

Fuel is calculated recursively: the fuel itself has mass, requiring additional fuel to carry it. The calculation repeats until additional fuel ≤ 0, summing all positive values.

## Supported Planets

| Planet | Gravity (m/s²) |
|--------|----------------|
| Earth  | 9.807 |
| Moon   | 1.62 |
| Mars   | 3.711 |

## Example Missions

**Apollo 11 style (28,801 kg spacecraft):**
1. Launch from Earth
2. Land on Moon
3. Launch from Moon
4. Land on Earth

**Total fuel required: 51,898 kg**

**Mars mission (14,606 kg spacecraft):**
1. Launch from Earth
2. Land on Mars
3. Launch from Mars
4. Land on Earth

**Total fuel required: 33,388 kg**

## API Examples

```elixir
# Single step calculation
{:ok, fuel} = AstroFuel.Fuel.calculate_step(:launch, :earth, 28_801)
# => {:ok, 19_772}

# Full mission
mission = AstroFuel.Mission.new(28_801)
{:ok, step} = AstroFuel.FlightStep.new(:launch, :earth)
mission = AstroFuel.Mission.add_step(mission, step)
result = AstroFuel.Mission.calculate(mission)
# => %{valid?: true, total_fuel: 19_772, step_details: [...], errors: []}
```

## Security Considerations

- Atom exhaustion prevention via whitelisted conversions instead of raw `String.to_existing_atom/1`
- Input validation at domain and LiveView layers
- CSRF protection via Phoenix defaults
- No database (in-memory only)

## Future Considerations

**`Mission.add_step/2` is O(n) per append** — Steps are stored in chronological order using `steps ++ [step]`, which copies the list on each addition. For typical missions (<10 steps) this is negligible, but for longer paths consider storing steps in reverse order internally and reversing only when displaying/calculating.

**`MissionLive` step fuel lookup is O(n) per row** — During render, each step row calls `Enum.find/2` over `step_details` to retrieve its fuel. With n steps this results in O(n²) total lookups. For larger missions, pre-index `step_details` by step ID in a map after calculation to enable O(1) lookup.

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)
