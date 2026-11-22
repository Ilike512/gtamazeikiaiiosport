extends RefCounted


static func forces(slip: float, longitudinal: float, capacity: float, peak_angle: float, slide_ratio: float, rolling_speed: float) -> Vector2:
	if capacity <= 0.0:
		return Vector2.ZERO
	var demand := longitudinal / capacity
	var normalized_slip := absf(slip) / maxf(peak_angle, 0.01)
	var lateral := normalized_slip * (2.0 - normalized_slip) if normalized_slip <= 1.0 else lerpf(
		1.0, slide_ratio, smoothstep(1.0, 3.15, normalized_slip))
	lateral *= smoothstep(0.08, 2.4, rolling_speed)
	var combined := Vector2(demand, -signf(slip) * lateral)
	var slide := smoothstep(1.0, 2.15, combined.length())
	return combined.limit_length(lerpf(1.0, slide_ratio, slide)) * capacity
