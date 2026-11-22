extends RefCounted
## 保留原着色器的完整绘制结果，再渐变去色；角色与机关不参与。
var originals: Array[Dictionary] = []
var transition: Tween
var amount := 0.0

func apply(room: Node, enabled: bool) -> void:
    if is_instance_valid(transition):
        transition.kill()
    if room == null:
        restore()
        return
    if enabled and originals.is_empty():
        visit(room)
    transition = room.get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    transition.tween_method(set_amount, amount, 1.0 if enabled else 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    if not enabled:
        transition.tween_callback(restore)

func set_amount(value: float) -> void:
    amount = value
    for record in originals:
        if is_instance_valid(record.node):
            record.effect.set_shader_parameter("pause_desaturation", value)

func restore() -> void:
    for record in originals:
        if is_instance_valid(record.node):
            record.node.material = record.material
            record.node.use_parent_material = record.inherit
    originals.clear()
    amount = 0.0

func visit(node: Node) -> void:
    if node.is_in_group("player") or node.is_in_group("echo") or node.is_in_group("replay_ghost"):
        return
    if node.name in [&"Mechanisms", &"StationSignals"] or node is CanvasLayer or node is Control:
        return
    if node.scene_file_path.begins_with("res://graybox/") and node.scene_file_path != "res://graybox/base_level.tscn":
        return
    if node is CanvasItem:
        var original: Material = node.material
        var effect := ShaderMaterial.new()
        var code := "shader_type canvas_item; void fragment() { COLOR = COLOR; }"
        if original is ShaderMaterial and original.shader != null:
            effect = original.duplicate()
            code = original.shader.code
        # 在原 shader 内插入去色，保留原有绘制。
        code = code.replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform float pause_desaturation = 0.0;")
        var opening := code.find("{", code.find("void fragment()"))
        var closing := opening + 1
        var depth := 1
        while depth > 0 and closing < code.length():
            if code[closing] == "{": depth += 1
            elif code[closing] == "}": depth -= 1
            closing += 1
        var filter := "\nfloat pause_gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)); COLOR.rgb = mix(COLOR.rgb, vec3(pause_gray), pause_desaturation);\n"
        code = code.insert(closing - 1, filter)
        var shader := Shader.new()
        shader.code = code
        effect.shader = shader
        originals.append({"node": node, "material": original, "inherit": node.use_parent_material, "effect": effect})
        node.use_parent_material = false
        node.material = effect
    for child in node.get_children():
        visit(child)
