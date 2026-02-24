# Flamethrower Controller & Burn Status Effect – Implementation Plan

## Overview

- **Flamethrower**: Continuous cone attack with tick-based damage. **Does 2 damage every tick always.** At level 9, on **burned** targets only: adds burn damage + base damage (2) on the tick.
- **Burn**: DoT with its **own** base damage of **5** (5 damage/s for 3s base), affected by damage mult, attack speed (tick interval), and duration. Visual: lingering ember particles on the target. **Burn damage floating text**: red-ish fire color.
- **Spread → cone angle**: Exact mapping will require iteration; use a reasonable initial mapping (e.g. 2→narrow, 24→wide).
- **BurnableComponent**: Add **at runtime** when first burn is applied (inject component if target doesn’t have it).

---

## 1. Burn Status Effect

### 1.1 Where it lives

- **Option A (recommended)**: New component **BurnableComponent** (or **BurnEffectComponent**) that can be added to any node that has a **HurtboxComponent** (and thus HealthComponent). When “apply burn” is called, the component starts a timer-based DoT and manages duration/refresh.
- **Option B**: A global **BurnManager** (autoload) that tracks active burns by target instance ID and applies damage via a timer; targets need no new node.
- **Recommendation**: **Option A** – a small component on the target. Easy to attach a visual child (particle emitter) to the same node; no global state; works for enemies and breakables that already have HurtboxComponent.

### 1.2 BurnableComponent (or “Burn” component) design

- **Scene**: `scenes/component/burnable_component.tscn` – Node (or Node2D) with script. Optional child: GPUParticles2D for embers (or add it in code when burn starts).
- **Script**: `burnable_component.gd`
  - **apply_burn(params)**: Called with a struct or set of args: `damage_per_second`, `duration_seconds`, `tick_interval` (or derived from attack_speed), `damage_mult`, `source` (optional). If already burning, either stack or refresh (see level 9: “burn timer refreshes on hit”).
  - Internal: `_burn_timer` (repeats every `tick_interval`), `_remaining_duration`, `_damage_per_tick` (= damage_per_second * tick_interval). Each tick: find HurtboxComponent on parent (or owner), call `hurtbox.apply_damage(_damage_per_tick, ...)` with **floating text color = red-ish fire** (and minimal/no sparks). When `_remaining_duration` hits 0, stop timer and hide/stop particle effect.
  - **Refresh behavior**: If “refresh on hit” (level 9): on new `apply_burn`, set `_remaining_duration` back to full duration (and optionally re-apply intensity). Otherwise: optional “stack” or “ignore” for overlapping burns.
- **Modifiers** (passed in by flamethrower controller when applying burn):
  - **Damage**: `damage_per_second * damage_mult` (player’s damage_multiplier).
  - **Attack speed**: `tick_interval = base_interval / attack_speed_mult` (e.g. base 1.0s → 0.9s at 10% attack speed).
  - **Duration**: `duration_seconds * duration_mult` (how long the burn lasts).

### 1.3 Who gets the component?

- **Enemies**: Add **BurnableComponent** to enemy scenes (e.g. basic_enemy, bat_enemy, barrel, crate). Or add it at runtime when first burn is applied (get_node_or_null; if null, instantiate and add BurnableComponent, then apply_burn). Latter avoids editing every enemy scene.
- **Breakables**: Same – add component to barrel, crate, crate_tower, or inject at runtime when applying burn.
- **Decision**: **Add at runtime** when first burn is applied. Flamethrower (or BurnableComponent caller) checks for BurnableComponent on target; if missing, instantiate and add it as child of target, then call apply_burn. No need to edit every enemy/breakable scene.

### 1.4 Burn visual

- **Simple**: When burn starts, add a **GPUParticles2D** (or CPUParticles2D) as child of the burnable node (or of the component node). Emit slow, upward/sideways embers; small orange/red particles. When burn ends, stop emitting and queue_free after a short delay (or one_shot with lifetime).
- **Asset**: Reuse or create a small “ember” texture; process material: low speed, gravity or upward drift, short lifetime. No need for Planck shader here.

---

## 2. Flamethrower Controller

### 2.1 Ownership and lifecycle

- Controller is under **player’s Abilities** node (like ball lightning). When flamethrower is unlocked (level 1), controller is added once and stays.
- Controller **spawns one FlamethrowerAbility instance** and keeps it as a child (or adds to foreground_layer at player position). The visual runs **continuously** (emitting = true) while the ability is active. So:
  - On level >= 1: add flamethrower visual as child of player (or to foreground, parented to player position/rotation). Position/rotation updated in `_process` so the cone follows aim (e.g. `player.last_move_direction` or aim joystick).
  - When level drops to 0 (e.g. game restart): remove the visual node.

### 2.2 Tick damage and overlap detection

- **Tick damage**: Always 2; at level 9 add burn damage on burned targets (see 2.6).
- **Timer**: Base tick rate **0.8 s**; reduced by upgrades (levels 2, 5, 8: each -0.2) and by **generic attack speed** (divide interval by `player.attack_speed_multiplier`). Clamp to MIN_TICK_INTERVAL (e.g. 0.05).
- **On tick**:
  1. Get flamethrower visual instance (the one we own).
  2. Get **HitboxComponent** from it; call `get_overlapping_areas()`. Filter to **HurtboxComponent**; collect parent nodes (enemies/breakables).
  3. For each target:
     - **Direct tick damage**: Level 9 only adds “burn damage as base” that applies to tick; otherwise direct tick damage = 0 (base damage 2 “only applies to burn”).
     - **Burn application**: Track per target “tick count in window” and “last tick time”. If same target was hit on 2 previous ticks within 4 s, this is the 3rd → call **apply_burn** on target’s BurnableComponent (or add component then apply). Level 9: “burn refreshes on hit” – so every hit refreshes burn duration; still only “apply” burn every 3 ticks (or we could apply every tick at level 9 for refresh – design choice: “refreshes on hit” = any flamethrower hit refreshes the burn timer).

### 2.3 Per-target tracking

- **Data structure**: Dictionary mapping target (e.g. `Node` or `RID`/instance_id) to `{ tick_count: int, last_tick_time: float }`.
- **Logic**: On each tick, for each target in overlap: increment tick_count (or set to 1 if not in dict). If `Time.get_ticks_msec()/1000.0 - last_tick_time > 4.0`, reset tick_count to 1. Then if `tick_count >= 3`, apply burn and optionally reset tick_count to 0 (so next burn in 3 more ticks). Update last_tick_time.

### 2.4 Spread and particle amount (from upgrades)

- **Spread**: Stored as numeric value; levels 1=2, 3=6, 6=12, 8=24. Passed to `flamethrower_ability.apply_parameters(..., spread_value, ...)`. Map spread (2,6,12,24) to cone angle in the ability script; **exact angles will require iteration** – start with a reasonable mapping (e.g. linear or small table).
- **Base particle amount**: Level 1 = base (e.g. 30); level 2 ×2 (60); level 5 ×1.5 (90); level 8 ×1.5 (135). So `_base_particle_amount` from a table or formula in `_apply_stats_from_level()`.

### 2.5 Upgrade summary (controller stats)

| Level | Effect |
|-------|--------|
| 1 | Unlock |
| 2 | Tick rate -0.2 (0.8→0.6), base pixels ×2 |
| 3 | Spread 150% → 6 (and hitbox) |
| 4 | Burn damage rate -0.2 (burn tick interval 1.0→0.8) |
| 5 | Tick rate -0.2 (0.6→0.4), base pixels ×1.5 |
| 6 | Spread +100% → 12 |
| 7 | Burn damage rate -0.2 (burn tick interval e.g. 0.8→0.6) |
| 8 | Tick rate -0.2 (0.4→0.2), base pixels ×1.5 & Spread +100% → 24 |
| 9 | Burn refreshes on flamethrower hit; flamethrower gets added base damage = burn damage (applies to tick, ignores “base only applies to burn”) |

- **Burn damage rate -0.2**: Interpret as burn’s damage tick interval reduced by 0.2 s (Level 4: 1.0 s → 0.8 s; level 7: 0.8 s → 0.6 s). So “5 damage per second” becomes “5 damage every 0.8 s” (6.25/s) with one upgrade.

### 2.6 Damage formula (locked in)

- **Burn**: Has its **own** base damage of **5** (5 damage/s for 3s). Not 5+2; the 2 is flamethrower’s tick damage only.
- **Direct tick damage**: **Always 2** (flamethrower base). This is separate from burn’s 5.
- **Level 9**: On targets that are **currently burning**, tick damage = **2 + burn damage** (e.g. per-tick burn amount). So flamethrower “adds base damage equal to burn damage” on burned targets; that extra is in addition to the 2. Burn also refreshes on any flamethrower hit.

---

## 3. Implementation Order

1. **BurnableComponent** (scene + script): apply_burn(damage_per_second, duration, tick_interval, damage_mult), internal timer, HurtboxComponent.apply_damage per tick. No visual yet.
2. **Burn visual**: Add simple ember GPUParticles2D to BurnableComponent (spawn when burn starts, remove when burn ends).
3. **Flamethrower controller – core**: Add/keep visual instance, tick timer (0.8s base, attack speed, level reductions), get overlapping areas from hitbox, per-target tick count and 4s window, every 3 ticks call apply_burn on target (add BurnableComponent if missing).
4. **Flamethrower controller – upgrades**: _apply_stats_from_level() for tick rate, spread, base particle amount, burn tick rate; apply_parameters() with spread and particle count; level 9 direct damage and burn refresh.
5. **Wire resources**: flamethrower_path.tres, lv2–lv9, upgrade_manager registration (if not already). Ensure flamethrower_ability is in StartingAbilityRegistry if it’s selectable.
6. **BurnableComponent**: Inject **at runtime** when first burn is applied (instantiate component, add to target, then apply_burn). No scene edits required for enemies/breakables.

---

## 4. Files to Create / Touch

| Item | Action |
|------|--------|
| `scenes/component/burnable_component.tscn` | Create (Node + script, optional particle child) |
| `scenes/component/burnable_component.gd` | Create (apply_burn, timer, damage tick, duration, refresh logic) |
| `scenes/ability/flamethrower_ability_controller/flamethrower_ability_controller.gd` | Implement tick, overlap, burn-every-3-ticks, apply_parameters, level 9 |
| `scenes/ability/flamethrower_ability/flamethrower_ability.gd` | Possibly map “spread” value (2,6,12,24) to cone angle if not already |
| `resources/upgrades/flamethrower*.tres` | Ensure lv2–lv9 descriptions match this plan |
| Enemy/breakable scenes | No edits; BurnableComponent added at runtime on first burn |
| `scenes/component/hurtbox_component.gd` | Add optional `floating_text_color: Color = null` to `apply_damage()` and pass to `floating_text.start(..., custom_color)` for burn damage (red-ish fire color). |

---

## 5. Implementation notes (confirmed)

- **Burn floating text**: Red-ish fire color. `floating_text.start()` already supports `custom_color`; HurtboxComponent needs an optional param (e.g. `floating_text_color`) and pass it through so burn damage uses it.
- **Flamethrower tick damage**: 2 always; at level 9 add burn damage on **burned** targets only.
- **Burn base damage**: 5 (its own; not 5+2).
- **Spread → cone angle**: Iterate in play; document initial mapping in code.
- **BurnableComponent**: Add at runtime when first burn is applied.
