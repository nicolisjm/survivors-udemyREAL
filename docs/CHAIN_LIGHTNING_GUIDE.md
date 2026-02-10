# Chain Lightning Ability – Step-by-Step Guide

This guide walks you through adding an unlockable Chain Lightning ability (like the axe). You’ll create the resource, the controller, the visual, and the upgrade wiring. Each step explains *why* so you can reuse the pattern later.

---

## Big picture

Chain Lightning will:

1. **Unlock** when the player picks “Chain Lightning” from the upgrade screen (one-time, like Blessed Axe).
2. **Fire on a timer** (e.g. every 3 seconds), like the axe and sword controllers.
3. **Pick a chain of enemies**: start from the player (or nearest enemy), then jump to the next closest enemy, then the next, up to a **configurable** number of chains.
4. **Deal damage** to each enemy in the chain (same damage or reduced per hop—your choice).
5. **Show a lightning visual** between each pair of points (zigzag lines, optional particles).

So you need:

- An **Ability resource** (like `axe.tres`) that points to the controller scene.
- A **controller** (Node + Timer) that picks targets, applies damage, and spawns the visual.
- A **visual scene** (Node2D + Line2D and/or particles) that draws lightning between a list of positions.
- **Upgrade manager** changes so Chain Lightning can appear in the pool and, when chosen, add the controller to the player.

---

## Step 1: Create the base Ability resource

**Goal:** Define the “Chain Lightning” unlock that shows in the upgrade screen and adds the controller when chosen.

**What to do:**

1. In the FileSystem, duplicate `axe.tres` (or create a new Resource) and save it as `chain_lightning.tres` under `resources/upgrades/`.
2. Set its **script** to `ability.gd` (same as axe – the one that has `ability_controller_scene`).
3. Set:
   - **ability_controller_scene** → leave empty for now; you’ll assign the controller scene after Step 3.
   - **id** → `"chain_lightning"` (unique string; you’ll use it in code).
   - **max_quantity** → `1` (one-time unlock).
   - **name** → e.g. `"Chain Lightning"`.
   - **description** → short text for the upgrade card.

**Why:** The player script already handles any `Ability` upgrade by adding `ability.ability_controller_scene.instantiate()` to the Abilities node. So once this resource points to your controller scene, picking it from the upgrade screen will add the controller and start the timer.

---

## Step 2: Create the Chain Lightning controller scene

**Goal:** A node that runs on a timer, picks a chain of enemies, applies damage, and spawns the visual.

**What to do:**

1. Create a new scene: root node **Node** (like `AxeAbilityController`), name it e.g. `ChainLightningAbilityController`.
2. Add a **Timer** child. Set `wait_time` (e.g. 3.0) and enable **Autostart**.
3. Attach a script to the root. In the script:
   - Export a `PackedScene` for the **chain lightning visual** (the scene you’ll build in Step 4).
   - Export or define a **max_chain_count** (e.g. 3 or 4) so the number of chains is configurable.
   - Store `base_damage`, `additional_damage_percent`, and `base_wait_time` like the axe controller.
   - In `_ready()`: connect `$Timer.timeout` to a function (e.g. `on_timer_timeout`) and connect `GameEvents.ability_upgrade_added` to handle rate/damage upgrades later.
   - In the timeout function:
     - Get the player and the `foreground_layer` (for spawning the visual). If either is null, return.
     - Build the **chain of positions** (see “Picking the chain” below).
     - **Apply damage** to each enemy in the chain (e.g. get each enemy’s `HurtboxComponent`/`HealthComponent` and call `damage()` with your computed damage).
     - **Spawn the visual**: instantiate your chain lightning visual scene, add it to `foreground_layer`, and give it the list of **global positions** (player → enemy1 → enemy2 → …) so it can draw the bolts.

**Picking the chain (algorithm):**

- Start list: `[player.global_position]`.
- Get all nodes in group `"enemy"` within a max range of the player (reuse the idea from `SwordAbilityController`: filter by distance).
- Sort enemies by distance from the **start point** (first the player, then from the last chosen enemy).
- Loop up to `max_chain_count` times: pick the closest enemy that isn’t already in the chain, add its position to the list, and add it to a “chosen enemies” list for applying damage.
- You now have an array of positions and an array of enemies. Deal damage to each chosen enemy; pass the position array to the visual.

**Why:** The controller owns *when* lightning fires and *who* it hits. The visual only receives positions and draws; that keeps logic and presentation separate.

---

## Step 3: Point the Ability resource at the controller

**Goal:** So that picking “Chain Lightning” from the upgrade screen actually adds your controller.

**What to do:**

1. Open `chain_lightning.tres`.
2. Set **ability_controller_scene** to your `ChainLightningAbilityController` scene (e.g. `res://scenes/ability/chain_lightning_ability_controller/chain_lightning_ability_controller.tscn`).

**Why:** When the player picks this upgrade, `player.gd` checks `if ability_upgrade is Ability` and then does `Abilities.add_child(ability.ability_controller_scene.instantiate())`. So the resource must reference the controller scene.

---

## Step 4: Add Chain Lightning to the upgrade pool

**Goal:** Make “Chain Lightning” appear as an option when the player levels up.

**What to do:**

1. In `upgrade_manager.gd`, preload `chain_lightning.tres` (same way you preload `upgrade_axe`).
2. In `_ready()`, add it to the pool: `upgrade_pool.add_item(upgrade_chain_lightning, 10)` (or whatever weight you like).
3. Optional: in `update_upgrade_pool()`, when the player picks chain lightning, add future upgrades like “chain_lightning_rate” or “chain_lightning_damage” to the pool (you can add those resources and logic later).

**Why:** The upgrade manager decides which upgrades are offered. Adding the resource to the pool is what makes it show up on the upgrade screen.

---

## Step 5: Lightning visual – Line2D zigzag

**Goal:** A scene that takes a list of global positions and draws a jagged “lightning” path between them.

**Why Line2D:** Particles are great for sparks and glow, but the *path* of the chain (A→B→C) is best drawn with a line. Line2D lets you set points; you’ll build points with small random offsets to get a lightning look.

**What to do:**

1. Create a new scene: root **Node2D** (e.g. `ChainLightningVisual`).
2. Add a **Line2D** child. Set **width** (e.g. 3–5), **default_color** (e.g. light blue/white). Optionally use **gradient** for a glow (e.g. bright center, transparent edges).
3. Add a script to the root. Provide a function that accepts an array of `Vector2` (e.g. `play(positions: Array)`):
   - Store the positions (convert to local if needed: `to_local(pos)`).
   - For each consecutive pair (A, B), generate **zigzag points** between A and B (see below), and add them to a single list of points for the Line2D.
   - Assign that list to `$Line2D.points` (or clear and add points).
   - Start a short **Timer** or **Tween** (e.g. 0.2–0.4 s), then call `queue_free()` so the bolt disappears.

**Zigzag between two points:**

- From A to B, walk along the segment. For every small step (e.g. 10–20 segments), compute a point along the line, then add a **random perpendicular offset** (so the line “jitters” sideways). Use `Vector2.RIGHT.rotated(direction.angle())` to get a perpendicular, then multiply by `randf_range(-offset, offset)`. That gives you a lightning-like path.

**Why:** Lightning in games is usually a line with random perpendicular noise. Doing this per segment (player→enemy1, enemy1→enemy2, …) gives you a full chain that’s easy to read and looks electric.

---

## Step 6 (optional): Add particles for impact or glow

**Goal:** Extra polish: sparks at each hit, or a soft glow along the line.

**What to do:**

1. Add a **GPUParticles2D** (or CPUParticles2D) as a sibling of the Line2D.
2. For **impact sparks**: emit a burst at each chain position when the lightning “hits”. You can do this by adding a small sub-scene that’s just a Particle with one short burst, then instancing it at each position when you build the lightning.
3. For **trail glow**: try a narrow, short-lived particle that emits along the line or from the Line2D’s points. This is more experimental; the Line2D alone is often enough.

**Why:** Particles sell the “electric” feel; Line2D sells the “chain” structure. Combining them is optional but can look great.

---

## Step 7: Wire damage from the controller

**Goal:** Ensure the controller applies damage to the right enemies at the right time.

**What to do:**

- In the controller’s timeout, after you’ve built the chain of enemies, loop over the chosen enemies and apply damage (e.g. get each one’s `HealthComponent` or go through their `HurtboxComponent` and call `health_component.damage(amount)`). Use the same pattern as your sword/axe: base damage × additional_damage_percent. You can optionally reduce damage per hop (e.g. 100% → 80% → 64%).
- Don’t put HitboxComponents on the lightning visual unless you want overlap-based damage; for a chain you usually want **instant** damage when the bolt is created, which is why the controller applies it directly.

**Why:** The controller already decided who was hit; applying damage there keeps one source of truth and avoids timing issues with hitboxes.

---

## Step 8 (optional): Rate and damage upgrades

**Goal:** “Chain Lightning Speed” and “Chain Lightning Damage” (or “Chain Count”) like axe_rate and axe_damage.

**What to do:**

1. Create `chain_lightning_rate.tres` and `chain_lightning_damage.tres` (or `chain_lightning_chains.tres`) as `AbilityUpgrade` resources with the right `id` strings.
2. In `update_upgrade_pool()`, when the chosen upgrade is the base chain lightning (`chosen_upgrade.id == upgrade_chain_lightning.id`), add those new upgrades to the pool.
3. In the controller’s `on_ability_upgrade_added`, if `upgrade.id == "chain_lightning_rate"`, reduce `$Timer.wait_time` (same formula as axe_rate). If `upgrade.id == "chain_lightning_damage"`, increase `additional_damage_percent`. If you add a “chains” upgrade, increase `max_chain_count` when that upgrade is applied.

**Why:** Same pattern as axe: one base unlock, then rate/damage (or chain count) become available in the pool only after the base is chosen.

---

## Quick reference

| Piece              | Purpose |
|--------------------|--------|
| `chain_lightning.tres` | Ability resource; shows on upgrade screen; points to controller scene. |
| Controller scene   | Timer + script: pick chain targets, apply damage, spawn visual with position list. |
| Visual scene       | Node2D + Line2D (zigzag between positions); optional particles. |
| Upgrade manager    | Preload chain_lightning, add to pool in `_ready()`; optionally add rate/damage in `update_upgrade_pool()`. |
| Player             | No change; already adds any `Ability`’s `ability_controller_scene` to Abilities. |

If you get stuck on a specific step (e.g. zigzag math, or how to get HealthComponent from an enemy), say which step and we can zoom in there with code.
