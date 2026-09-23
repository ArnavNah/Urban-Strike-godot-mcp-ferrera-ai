class_name CombatDirector
extends Node

## GDD Section 12 & Phase 10B: Manages attack tokens, projectile danger budgets, and battlefield pressure.
## Enforces low-difficulty Survivors-style enemy attack throttling:
## - Only a small number of enemies may actively attack at once.
## - Maximum 1 active homing lock against the player.
## - Maximum 1 heavy attack (Tank, Rocket Volley, SAM, Mortar) in progress at once.
## - Global projectile danger cap to prevent bullet hell.
## - Watchdog cleanup for expired/leaked leases and danger reservations.

# Default capacities by wave
const WAVE_TOKEN_CONFIG := {
	1: { "ground_tokens": 2, "air_tokens": 1, "max_attackers": 2, "danger_cap": 6 },
	2: { "ground_tokens": 2, "air_tokens": 1, "max_attackers": 2, "danger_cap": 7 },
	3: { "ground_tokens": 2, "air_tokens": 1, "max_attackers": 3, "danger_cap": 8 },
	4: { "ground_tokens": 2, "air_tokens": 2, "max_attackers": 3, "danger_cap": 9 },
	5: { "ground_tokens": 2, "air_tokens": 2, "max_attackers": 4, "danger_cap": 10 },
	6: { "ground_tokens": 2, "air_tokens": 2, "max_attackers": 4, "danger_cap": 11 },
	7: { "ground_tokens": 2, "air_tokens": 2, "max_attackers": 4, "danger_cap": 12 },
	8: { "ground_tokens": 3, "air_tokens": 2, "max_attackers": 5, "danger_cap": 14 },
	9: { "ground_tokens": 3, "air_tokens": 2, "max_attackers": 5, "danger_cap": 16 },
	10: { "ground_tokens": 2, "air_tokens": 2, "max_attackers": 4, "danger_cap": 16 }
}

# Token costs by attack type
const TOKEN_COST_INFANTRY: int = 1
const TOKEN_COST_TURRET: int = 1
const TOKEN_COST_AIR_SCOUT: int = 1
const TOKEN_COST_AIR_GUNSHIP: int = 2
const TOKEN_COST_TANK_CANNON: int = 1
const TOKEN_COST_ROCKET_VOLLEY: int = 2
const TOKEN_COST_SAM_MISSILE: int = 2
const TOKEN_COST_MORTAR_STRIKE: int = 2
const TOKEN_COST_JAMMER_OFFENSE: int = 1

# Projectile danger costs
const DANGER_COST_BULLET: int = 1
const DANGER_COST_CANNON_SHELL: int = 3
const DANGER_COST_ROCKET: int = 3
const DANGER_COST_HOMING_MISSILE: int = 4
const DANGER_COST_MORTAR_ZONE: int = 4
const DANGER_COST_BOSS_ORDNANCE: int = 3

@export var current_wave: int = 1
@export var max_ground_attack_slots: int = 2
@export var max_air_attack_slots: int = 1
@export var max_concurrent_attackers: int = 2
@export var max_projectile_danger: int = 6
@export var slot_lease_duration: float = 6.0
var total_leases_granted: int = 0
var last_rejection_reasons: Dictionary = {
	"alive": 0,
	"control": 0,
	"deployment": 0,
	"monopoly": 0,
	"max_attackers": 0,
	"tokens": 0,
	"heavy": 0,
	"homing": 0,
	"danger": 0
}

# Active token leases: Dictionary[Node3D, Dictionary]
# Structure: {
#   "tokens": int,
#   "is_air": bool,
#   "is_heavy": bool,
#   "is_homing": bool,
#   "danger": int,
#   "expiry": float,
#   "attack_type": String
# }
var _active_leases: Dictionary = {}

# Active heavy attackers and homing lock holders (for fast constraint queries)
var _active_heavy_attackers: Array[Node3D] = []
var _active_homing_lock_holders: Array[Node3D] = []

# Waiting enemies (for fairness and monopoly prevention)
var _waiting_enemies: Array[Node3D] = []
var _enemy_last_release_time: Dictionary = {} # Node3D -> float

# Projectile danger tracking
# Key: Variant (Node or int ID) -> Dictionary: { "amount": int, "expiry": float }
var _active_danger_reservations: Dictionary = {}
var current_danger_used: int = 0

# Pausable gameplay time
var _gameplay_time: float = 0.0

# Watchdog telemetry
var watchdog_reclaimed_leases: int = 0
var watchdog_reclaimed_danger: int = 0

# Player damage rate tracking (damage per minute)
var _damage_history: Array[Dictionary] = [] # Array of { "time": float, "amount": float }

static var instance: CombatDirector

func _enter_tree() -> void:
	instance = self
	add_to_group("combat_director")

func _ready() -> void:
	set_wave(current_wave)
	if EventBus and EventBus.has_signal("wave_started"):
		EventBus.wave_started.connect(func(wave_num: int, _announcement: String): set_wave(wave_num))

func _process(delta: float) -> void:
	if not get_tree().paused:
		_gameplay_time += delta
	_cleanup_expired(delta)

## Sets capacities and danger budget based on current wave
func set_wave(wave: int) -> void:
	current_wave = clampi(wave, 1, 10)
	var cfg: Dictionary = WAVE_TOKEN_CONFIG.get(current_wave, WAVE_TOKEN_CONFIG[1])
	max_ground_attack_slots = cfg["ground_tokens"]
	max_air_attack_slots = cfg["air_tokens"]
	max_concurrent_attackers = cfg["max_attackers"]
	max_projectile_danger = cfg["danger_cap"]
	_cleanup_slots()

var active_heavy_attacks: int:
	get: return _active_heavy_attackers.size()

var active_homing_locks: int:
	get: return _active_homing_lock_holders.size()

## Backwards-compatible slot limit setter
func set_wave_limits(ground: int, air: int) -> void:
	if ground == 0 and air == 0:
		# Explicit combat suppression (e.g., player death or victory)
		max_ground_attack_slots = 0
		max_air_attack_slots = 0
		max_concurrent_attackers = 0
		_cleanup_slots()
		return

	var cfg: Dictionary = WAVE_TOKEN_CONFIG.get(current_wave, WAVE_TOKEN_CONFIG[1])
	if ground > 0:
		max_ground_attack_slots = ground
	else:
		max_ground_attack_slots = int(cfg.get("ground_tokens", 2))

	if air > 0:
		max_air_attack_slots = air
	else:
		# Safeguard: Never overwrite positive air capacity with zero from unconfigured wave definitions
		max_air_attack_slots = int(cfg.get("air_tokens", 1))

	max_concurrent_attackers = maxi(2, max_ground_attack_slots + max_air_attack_slots)
	_cleanup_slots()

## Primary Phase 10B attack permission request
func request_attack_permission(
	enemy: Node3D,
	token_cost: int = 1,
	is_air: bool = false,
	is_heavy: bool = false,
	is_homing: bool = false,
	danger_cost: int = 1,
	attack_type: String = "ordinary"
) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		last_rejection_reasons["alive"] += 1
		return false
	if "is_alive" in enemy and not enemy.is_alive:
		last_rejection_reasons["alive"] += 1
		return false

	# Pause / player control safety: disallow enemy attack leases if player is dead or control disabled
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		if "is_alive" in player and not player.is_alive:
			last_rejection_reasons["control"] += 1
			return false
		if "_control_enabled" in player and not player._control_enabled:
			last_rejection_reasons["control"] += 1
			return false

	# Deployment safety: disallow attack leases while deployment countdown is active
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if is_instance_valid(wm) and wm.has_method("is_deployment_active") and wm.is_deployment_active():
		last_rejection_reasons["deployment"] += 1
		return false

	_cleanup_slots()
	var now := _gameplay_time

	# 1. If enemy already holds this lease, refresh duration
	if _active_leases.has(enemy):
		var existing: Dictionary = _active_leases[enemy]
		existing["expiry"] = now + slot_lease_duration
		return true

	# 2. Prevent single enemy from monopolizing tokens if others are waiting
	var last_rel: float = _enemy_last_release_time.get(enemy, -100.0)
	if (now - last_rel) < 0.6 and _waiting_enemies.size() > 0 and not _waiting_enemies.has(enemy):
		_add_to_waiting(enemy)
		last_rejection_reasons["monopoly"] += 1
		return false

	# 3. Attacker Count & Category Token Constraints
	var ground_used: int = get_ground_tokens_used()
	var air_used: int = get_air_tokens_used()
	var effective_tokens: int = token_cost

	if is_air:
		if max_air_attack_slots <= 0:
			_add_to_waiting(enemy)
			last_rejection_reasons["tokens"] += 1
			return false
		if (air_used + effective_tokens) > max_air_attack_slots:
			if air_used == 0 and max_air_attack_slots > 0:
				effective_tokens = max_air_attack_slots
			else:
				_add_to_waiting(enemy)
				last_rejection_reasons["tokens"] += 1
				return false
	else:
		if max_ground_attack_slots <= 0:
			_add_to_waiting(enemy)
			last_rejection_reasons["tokens"] += 1
			return false
		if (ground_used + effective_tokens) > max_ground_attack_slots:
			if ground_used == 0 and max_ground_attack_slots > 0:
				effective_tokens = max_ground_attack_slots
			else:
				_add_to_waiting(enemy)
				last_rejection_reasons["tokens"] += 1
				return false
		if _active_leases.size() >= max_concurrent_attackers and air_used == 0:
			_add_to_waiting(enemy)
			last_rejection_reasons["max_attackers"] += 1
			return false

	# 5. Heavy Attack Mutual Exclusion: At most ONE heavy attack across the entire battlefield
	if is_heavy and _active_heavy_attackers.size() > 0:
		_add_to_waiting(enemy)
		last_rejection_reasons["heavy"] += 1
		return false

	# 6. Homing Lock Constraint: At most ONE active homing lock against the player
	if is_homing and _active_homing_lock_holders.size() > 0:
		_add_to_waiting(enemy)
		last_rejection_reasons["homing"] += 1
		return false

	# 7. Projectile Danger Budget Capacity Check
	if (current_danger_used + danger_cost) > max_projectile_danger:
		_add_to_waiting(enemy)
		last_rejection_reasons["danger"] += 1
		return false

	# All checks passed: Grant the lease
	var lease := {
		"tokens": effective_tokens,
		"is_air": is_air,
		"is_heavy": is_heavy,
		"is_homing": is_homing,
		"danger": danger_cost,
		"expiry": now + slot_lease_duration,
		"attack_type": attack_type
	}
	_active_leases[enemy] = lease
	current_danger_used += danger_cost
	total_leases_granted += 1

	if is_heavy:
		_active_heavy_attackers.append(enemy)
	if is_homing:
		_active_homing_lock_holders.append(enemy)

	_waiting_enemies.erase(enemy)
	return true

## Releases an active attack permission lease
func release_attack_permission(enemy: Node3D) -> void:
	if not _active_leases.has(enemy):
		_waiting_enemies.erase(enemy)
		return

	var lease: Dictionary = _active_leases[enemy]
	var danger_cost: int = lease.get("danger", 0)

	# If danger budget was reserved by this lease and hasn't yet transitioned to in-flight projectile
	if danger_cost > 0:
		current_danger_used = maxi(0, current_danger_used - danger_cost)

	if lease.get("is_heavy", false):
		_active_heavy_attackers.erase(enemy)
	if lease.get("is_homing", false):
		_active_homing_lock_holders.erase(enemy)

	_active_leases.erase(enemy)
	_enemy_last_release_time[enemy] = _gameplay_time
	_waiting_enemies.erase(enemy)

## Backwards-compatible request slot facade
func request_attack_slot(enemy: Node3D, is_air: bool = false) -> bool:
	return request_attack_permission(enemy, 1, is_air, false, false, 1)

## Backwards-compatible release slot facade
func release_attack_slot(enemy: Node3D, _is_air: bool = false) -> void:
	release_attack_permission(enemy)

## Check if enemy currently holds an attack slot or permission
func has_attack_slot(enemy: Node3D, _is_air: bool = false) -> bool:
	return _active_leases.has(enemy)

func has_attack_permission(enemy: Node3D) -> bool:
	return _active_leases.has(enemy)

## Standalone projectile danger capacity reservation (for projectiles launched or telegraph zones)
func reserve_danger_capacity(source: Variant, amount: int = 1, timeout: float = 4.0) -> bool:
	if (current_danger_used + amount) > max_projectile_danger:
		return false
	current_danger_used += amount
	_active_danger_reservations[source] = {
		"amount": amount,
		"expiry": _gameplay_time + timeout
	}
	return true

## Standalone projectile danger release (called on hit, expiration, or cancellation)
func release_danger_capacity(source: Variant, fallback_amount: int = 0) -> void:
	if _active_danger_reservations.has(source):
		var res_info: Dictionary = _active_danger_reservations[source]
		var amt: int = res_info.get("amount", fallback_amount)
		current_danger_used = maxi(0, current_danger_used - amt)
		_active_danger_reservations.erase(source)
	elif source == null and fallback_amount > 0:
		current_danger_used = maxi(0, current_danger_used - fallback_amount)

## Transfer danger capacity from enemy lease to in-flight projectile
func transfer_danger_to_projectile(enemy: Node3D, projectile: Variant, timeout: float = 4.0) -> void:
	if _active_leases.has(enemy):
		var lease: Dictionary = _active_leases[enemy]
		var danger: int = lease.get("danger", 0)
		if danger > 0:
			# Zero out lease danger so release_attack_permission doesn't double-subtract
			lease["danger"] = 0
			_active_danger_reservations[projectile] = {
				"amount": danger,
				"expiry": _gameplay_time + timeout
			}

func get_ground_tokens_used() -> int:
	var total: int = 0
	for enemy in _active_leases.keys():
		var lease: Dictionary = _active_leases[enemy]
		if not lease.get("is_air", false):
			total += int(lease.get("tokens", 1))
	return total

func get_air_tokens_used() -> int:
	var total: int = 0
	for enemy in _active_leases.keys():
		var lease: Dictionary = _active_leases[enemy]
		if lease.get("is_air", false):
			total += int(lease.get("tokens", 1))
	return total

func get_active_attackers_count() -> int:
	return _active_leases.size()

func get_active_homing_count() -> int:
	return _active_homing_lock_holders.size()

func get_active_heavy_count() -> int:
	return _active_heavy_attackers.size()

## Record damage dealt to player for telemetry DPM calculation
func record_player_damage(amount: float) -> void:
	_damage_history.append({ "time": _gameplay_time, "amount": amount })

## Calculates single shared enemy damage progression multiplier:
## multiplier = min(1.0 + 0.10 * elapsed_minutes, 2.5)
func get_damage_progression_multiplier() -> float:
	var elapsed_minutes: float = _gameplay_time / 60.0
	return minf(1.0 + 0.10 * elapsed_minutes, 2.5)

## Global static helper for querying the active combat progression damage multiplier
static func get_damage_multiplier() -> float:
	if instance:
		return instance.get_damage_progression_multiplier()
	return 1.0

func get_player_damage_per_minute() -> float:
	var cutoff := _gameplay_time - 60.0
	var valid_hist: Array[Dictionary] = []
	var total: float = 0.0
	for entry in _damage_history:
		if entry["time"] >= cutoff:
			valid_hist.append(entry)
			total += float(entry["amount"])
	_damage_history = valid_hist
	return total

func _add_to_waiting(enemy: Node3D) -> void:
	if is_instance_valid(enemy) and not _waiting_enemies.has(enemy):
		_waiting_enemies.append(enemy)

## Watchdog cleanup: clears expired leases, dead node references, and leaked danger reservations
func _cleanup_expired(_delta: float) -> void:
	var now := _gameplay_time

	# 1. Clean token leases
	var expired_leases: Array[Node3D] = []
	for e in _active_leases.keys():
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			expired_leases.append(e)
		elif "is_alive" in e and not e.is_alive:
			expired_leases.append(e)
		elif now > _active_leases[e].get("expiry", 0.0):
			expired_leases.append(e)

	for exp_e in expired_leases:
		release_attack_permission(exp_e)
		watchdog_reclaimed_leases += 1

	# 2. Clean standalone danger reservations
	var expired_danger: Array[Variant] = []
	for key in _active_danger_reservations.keys():
		var is_valid_source := true
		if key is Object:
			if not is_instance_valid(key) or (key is Node and (key as Node).is_queued_for_deletion()):
				is_valid_source = false
		if not is_valid_source or now > _active_danger_reservations[key].get("expiry", 0.0):
			expired_danger.append(key)

	for exp_key in expired_danger:
		var amt: int = _active_danger_reservations[exp_key].get("amount", 0)
		current_danger_used = maxi(0, current_danger_used - amt)
		_active_danger_reservations.erase(exp_key)
		watchdog_reclaimed_danger += 1

	# 3. Clean waiting enemies
	var valid_waiting: Array[Node3D] = []
	for w in _waiting_enemies:
		if is_instance_valid(w) and not w.is_queued_for_deletion():
			valid_waiting.append(w)
	_waiting_enemies = valid_waiting

	# 4. Clean heavy & homing arrays
	var valid_heavy: Array[Node3D] = []
	for h in _active_heavy_attackers:
		if is_instance_valid(h) and _active_leases.has(h):
			valid_heavy.append(h)
	_active_heavy_attackers = valid_heavy

	var valid_homing: Array[Node3D] = []
	for hm in _active_homing_lock_holders:
		if is_instance_valid(hm) and _active_leases.has(hm):
			valid_homing.append(hm)
	_active_homing_lock_holders = valid_homing

	# 5. Clean release timestamps for dead enemies
	for rel_key in _enemy_last_release_time.keys():
		if not is_instance_valid(rel_key) or rel_key.is_queued_for_deletion():
			_enemy_last_release_time.erase(rel_key)

func _cleanup_slots() -> void:
	_cleanup_expired(0.0)

## Comprehensive telemetry for DebugCanvas and test verification
func get_debug_combat_telemetry() -> Dictionary:
	_cleanup_slots()
	var ground_names: Array[String] = []
	var air_names: Array[String] = []
	for e in _active_leases.keys():
		if is_instance_valid(e):
			if _active_leases[e].get("is_air", false):
				air_names.append(e.name)
			else:
				ground_names.append(e.name)

	return {
		"wave": current_wave,
		"ground_used": get_ground_tokens_used(),
		"ground_max": max_ground_attack_slots,
		"ground_holders": ground_names,
		"air_used": get_air_tokens_used(),
		"air_max": max_air_attack_slots,
		"air_holders": air_names,
		"attackers_count": _active_leases.size(),
		"max_attackers": max_concurrent_attackers,
		"danger_used": current_danger_used,
		"danger_max": max_projectile_danger,
		"active_homing_locks": _active_homing_lock_holders.size(),
		"active_heavy_attacks": _active_heavy_attackers.size(),
		"waiting_enemies_count": _waiting_enemies.size(),
		"watchdog_reclaimed_leases": watchdog_reclaimed_leases,
		"watchdog_reclaimed_danger": watchdog_reclaimed_danger,
		"total_leases_granted": total_leases_granted,
		"rejection_reasons": last_rejection_reasons.duplicate(),
		"player_dpm": get_player_damage_per_minute()
	}

## Backwards-compatible slot info dictionary
func get_debug_slot_info() -> Dictionary:
	return get_debug_combat_telemetry()
