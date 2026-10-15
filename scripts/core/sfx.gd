extends Node
## 程序化音效库（Autoload: Sfx）
##
## 全部音频在启动时用代码合成（AudioStreamWAV），工程不含任何外部音频素材。
## 音色方向对齐设定文档：「冷峻、潮湿、金属回声、低饱和霓虹」。

const RATE := 22050
const VOICES := 12

var _bank: Dictionary = {}          # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20240917
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_bank()


# ================= 播放接口 =================

func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _bank.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _bank[sound]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.play()


func play_varied(sound: String, volume_db: float = 0.0, spread: float = 0.12) -> void:
	play(sound, volume_db, 1.0 + _rng.randf_range(-spread, spread))


# ================= 合成工具 =================

func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var a := PackedFloat32Array()
	a.resize(n)
	return a


## 简易一阶低通，让噪声听起来更"闷"
func _lowpass(src: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var alpha := clampf(TAU * cutoff / float(RATE), 0.0, 1.0)
	var prev := 0.0
	for i in src.size():
		prev = prev + alpha * (src[i] - prev)
		out[i] = prev
	return out


func _noise(seconds: float, seed_value: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var a := _buf(seconds)
	for i in a.size():
		a[i] = r.randf_range(-1.0, 1.0)
	return a


# ================= 音效构建 =================

func _build_bank() -> void:
	# ---- 打击 ----
	_bank["hit_light"] = _stream(_gen_impact(0.11, 520.0, 2600.0, 46.0, 0.55, 11))
	_bank["hit_heavy"] = _stream(_gen_impact(0.26, 180.0, 900.0, 20.0, 0.85, 22))
	_bank["hit_crit"] = _stream(_gen_impact(0.32, 120.0, 3400.0, 16.0, 0.95, 33))
	_bank["hit_blocked"] = _stream(_gen_metal(0.14, 1500.0, 30.0, 0.5))

	# ---- 防御 ----
	_bank["guard"] = _stream(_gen_metal(0.18, 820.0, 22.0, 0.55))
	_bank["parry"] = _stream(_gen_parry())
	_bank["guard_break"] = _stream(_gen_sweep(0.42, 420.0, 90.0, 0.9, true))

	# ---- 铳 ----
	_bank["gun_fire"] = _stream(_gen_sweep(0.16, 1400.0, 260.0, 0.7, false))
	_bank["gun_overheat"] = _stream(_gen_noise_burst(0.5, 0.6, 3000.0))
	_bank["gun_ready"] = _stream(_gen_beep(0.08, 1800.0, 0.35))

	# ---- 移动 ----
	_bank["jump"] = _stream(_gen_sweep(0.12, 260.0, 620.0, 0.42, false))
	_bank["dash"] = _stream(_gen_noise_burst(0.2, 0.5, 1400.0))
	_bank["land"] = _stream(_gen_impact(0.13, 120.0, 700.0, 42.0, 0.5, 44))
	_bank["footstep"] = _stream(_gen_noise_burst(0.07, 0.22, 900.0))

	# ---- 幽灵 ----
	_bank["ghost_enter"] = _stream(_gen_sweep(0.45, 900.0, 180.0, 0.42, true))
	_bank["ghost_exit"] = _stream(_gen_sweep(0.35, 200.0, 1100.0, 0.42, true))
	_bank["probe"] = _stream(_gen_beep(0.22, 1300.0, 0.3))
	_bank["hack_tick"] = _stream(_gen_beep(0.045, 2100.0, 0.22))
	_bank["hack_done"] = _stream(_gen_chord([660.0, 990.0, 1320.0], 0.34, 0.32))
	_bank["hack_fail"] = _stream(_gen_chord([300.0, 220.0], 0.3, 0.34))

	# ---- 拾取 / 经济 ----
	_bank["shard"] = _stream(_gen_beep(0.09, 2400.0, 0.28))
	_bank["coin"] = _stream(_gen_chord([1300.0, 1950.0], 0.14, 0.3))
	_bank["pickup"] = _stream(_gen_chord([880.0, 1320.0], 0.16, 0.3))
	_bank["heal"] = _stream(_gen_chord([520.0, 780.0, 1040.0], 0.42, 0.28))

	# ---- 敌人 ----
	_bank["enemy_hurt"] = _stream(_gen_impact(0.1, 300.0, 1500.0, 40.0, 0.5, 55))
	_bank["enemy_die"] = _stream(_gen_sweep(0.42, 700.0, 70.0, 0.6, true))
	_bank["elite_die"] = _stream(_gen_chord([180.0, 240.0, 90.0], 0.75, 0.6))
	_bank["enemy_alert"] = _stream(_gen_beep(0.16, 980.0, 0.32))
	_bank["enemy_attack"] = _stream(_gen_sweep(0.14, 700.0, 300.0, 0.5, false))

	# ---- 玩家 ----
	_bank["player_hurt"] = _stream(_gen_sweep(0.3, 520.0, 130.0, 0.75, true))
	_bank["player_die"] = _stream(_gen_chord([320.0, 200.0, 120.0, 70.0], 1.5, 0.62))
	_bank["revive"] = _stream(_gen_chord([220.0, 440.0, 880.0, 1760.0], 1.1, 0.5))

	# ---- 交互 / 场景 ----
	_bank["door_open"] = _stream(_gen_sweep(0.55, 180.0, 520.0, 0.4, true))
	_bank["chest_open"] = _stream(_gen_chord([440.0, 660.0, 880.0, 1100.0], 0.6, 0.36))
	_bank["reward_appear"] = _stream(_gen_chord([392.0, 587.0, 784.0], 0.5, 0.34))
	_bank["terminal"] = _stream(_gen_beep(0.12, 1600.0, 0.3))
	_bank["alarm"] = _stream(_gen_alarm())

	# ---- UI ----
	_bank["ui_move"] = _stream(_gen_beep(0.05, 1200.0, 0.25))
	_bank["ui_confirm"] = _stream(_gen_chord([760.0, 1140.0], 0.16, 0.32))
	_bank["ui_cancel"] = _stream(_gen_chord([420.0, 300.0], 0.14, 0.3))
	_bank["ui_deny"] = _stream(_gen_chord([220.0, 165.0], 0.22, 0.34))
	_bank["intel"] = _stream(_gen_chord([523.0, 659.0, 784.0, 1046.0], 0.9, 0.28))

	# ---- Boss ----
	_bank["boss_roar"] = _stream(_gen_roar())
	_bank["boss_phase"] = _stream(_gen_chord([110.0, 165.0, 220.0, 330.0], 1.2, 0.55))


# ================= 波形生成器 =================

## 冲击：噪声 + 下滑音 + 指数包络
func _gen_impact(seconds: float, f_start: float, f_end: float, decay: float, noise_mix: float, seed_value: int) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var k := t / seconds
		var f: float = lerpf(f_start, f_end, k)
		phase += TAU * f / float(RATE)
		var env: float = exp(-t * decay)
		var tone := sin(phase)
		var noise := r.randf_range(-1.0, 1.0)
		out[i] = (tone * (1.0 - noise_mix) + noise * noise_mix) * env
	return _lowpass(out, 6000.0)


## 金属撞击：多个非谐波正弦
func _gen_metal(seconds: float, base: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [1.0, 1.73, 2.41, 3.17, 4.53]
	for i in n:
		var t := float(i) / float(RATE)
		var env: float = exp(-t * decay)
		var v := 0.0
		for k in partials.size():
			var f: float = base * float(partials[k])
			v += sin(TAU * f * t) / float(k + 1)
		out[i] = v * env * amp
	return _lowpass(out, 9000.0)


## 完美格挡：高频金属 + 上扬泛音
func _gen_parry() -> PackedFloat32Array:
	var seconds := 0.3
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env: float = exp(-t * 16.0)
		var sweep := 2400.0 + 5200.0 * t
		var v := sin(TAU * sweep * t) * 0.55
		v += sin(TAU * 1900.0 * t) * 0.35 * exp(-t * 22.0)
		v += sin(TAU * 3800.0 * t) * 0.2 * exp(-t * 30.0)
		out[i] = v * env
	return _lowpass(out, 11000.0)


## 扫频：可选加噪声（用于"撕裂"感）
func _gen_sweep(seconds: float, f_start: float, f_end: float, amp: float, noisy: bool) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 777
	for i in n:
		var t := float(i) / float(RATE)
		var k := t / seconds
		var f: float = lerpf(f_start, f_end, k)
		phase += TAU * f / float(RATE)
		var env: float = exp(-t * (2.6 / max(seconds, 0.01)))
		var v := sin(phase)
		if noisy:
			v = v * 0.7 + r.randf_range(-1.0, 1.0) * 0.3
		out[i] = v * env * amp
	return _lowpass(out, 7000.0)


func _gen_noise_burst(seconds: float, amp: float, cutoff: float) -> PackedFloat32Array:
	var src := _noise(seconds, _rng.randi())
	var out := PackedFloat32Array()
	out.resize(src.size())
	for i in src.size():
		var t := float(i) / float(RATE)
		out[i] = src[i] * exp(-t * (3.4 / max(seconds, 0.01))) * amp
	return _lowpass(out, cutoff)


func _gen_beep(seconds: float, freq: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var attack: float = clampf(t / 0.005, 0.0, 1.0)
		var release: float = clampf((seconds - t) / 0.02, 0.0, 1.0)
		out[i] = sin(TAU * freq * t) * amp * attack * release
	return out


func _gen_chord(freqs: Array, seconds: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env: float = exp(-t * (2.4 / max(seconds, 0.05)))
		var attack: float = clampf(t / 0.012, 0.0, 1.0)
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * float(freqs[k]) * t) / float(k + 1)
		out[i] = v * env * attack * amp
	return _lowpass(out, 8000.0)


func _gen_alarm() -> PackedFloat32Array:
	var seconds := 0.9
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var f: float = 720.0 if fmod(t, 0.45) < 0.24 else 520.0
		var gate: float = 1.0 if fmod(t, 0.45) < 0.34 else 0.0
		out[i] = sin(TAU * f * t) * 0.3 * gate
	return out


func _gen_roar() -> PackedFloat32Array:
	var seconds := 1.6
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var k := t / seconds
		var f: float = lerpf(90.0, 42.0, k) * (1.0 + 0.16 * sin(TAU * 7.0 * t))
		phase += TAU * f / float(RATE)
		var env: float = sin(PI * clampf(k, 0.0, 1.0))
		var v := sin(phase) * 0.7 + sin(phase * 2.02) * 0.3
		v += r.randf_range(-1.0, 1.0) * 0.18
		out[i] = v * env * 0.72
	return _lowpass(out, 2600.0)
