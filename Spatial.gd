extends Node3D

class TreeBit extends RefCounted:
    # storage
    var position = Vector3()
    var size = 1.0
    var parent = null
    var children = []
    var end_ring = []
    
    # used for generation
    var juice = 0.0
    
    # configurables
    var wander_rate_big = 0.5
    var wander_rate_small = 1.0
    var distance_rate = 2.0
    var shrink_rate = 0.01
    var split_chance = 0.5
    var split_proportion_min = 0.05
    var split_proportion_max = 0.95
    var split_width_randomness = 1.0
    var juice_gain_rate = 0.2
    
    func add_children():
        var world = Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("World")[0]
        var heading : Vector3 = Vector3.UP
        if parent:
            heading = (position - parent.position).normalized()
            if heading.y < 0.0 or size > 0.3:
                heading = heading.lerp(Vector3.UP, 0.2).normalized()
        
        end_ring = []
        var vert_count = int(size*8) + 1
        if vert_count < 3:
            vert_count = 3
        
        for i in range(vert_count):
            var rad = i/float(vert_count) * PI * 2.0
            #var v = Vector3(sin(rad), 0, cos(rad)) * size
            var v = Vector3(sin(rad), cos(rad), 0) * size
            var t : Transform3D = Transform3D.IDENTITY
            t = t.looking_at(heading, Vector3.UP + Vector3(0.0001, 0.00008981, -0.000014389))
            v = t.basis * (v)
            end_ring.push_back(v + position)
        
        juice += juice_gain_rate
        
        var count = 2 if randf() < (split_chance * juice) else 1
        
        if count > 1:
            juice = 0.0
        
        var areas = []
        
        if count == 1:
            areas = [1.0]
        else:
            var prop = lerp(split_proportion_min, split_proportion_max, randf())
            areas = [prop, (1.0 - prop)]
        
        for i in count:
            #var proportion = sqrt(areas[i])
            var proportion = sqrt(areas[i])
            var next_size = (size - (randf()*0.5 + 0.5) * shrink_rate) * proportion
            if next_size > 0.0:
                var dir = heading
                var wander_rate = lerp(wander_rate_small, wander_rate_big, next_size)
                dir += (Vector3(randf(), randf(), randf()) - Vector3.ONE*0.5) * wander_rate
                dir = dir.normalized()
                
                var next_pos = position + dir * size * lerp(0.75, 1.25, randf()) * distance_rate
                if next_pos.y > 0.0:
                    var bit = TreeBit.new()
                    bit.position = next_pos
                    bit.size = next_size
                    bit.parent = self
                    bit.juice = juice
                    children.push_back(bit)
        
        for i in range(children.size()):
            for j in range(children.size()):
                var diff = children[i].position - children[j].position
                var radius = children[i].size + children[j].size
                var shove = diff.normalized() * radius * lerp(0.25, randf()*0.5 + 0.25, split_width_randomness)
                children[i].position += shove
                children[j].position -= shove
        
        
        for child in children:
            child.add_children()

var vec3_quad = [
    Vector3(-1, 0, -1),
    Vector3(-1, 0,  1),
    Vector3( 1, 0, -1),
    Vector3( 1, 0,  1),
]
var vec2_quad = [
    Vector2(0, 0),
    Vector2(0, 1),
    Vector2(1, 0),
    Vector2(1, 1),
]

func build_leaf_mat():
    var mat = StandardMaterial3D.new()
    mat.albedo_texture = preload("res://art/just leaves.png")
    mat.params_diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
    mat.params_use_alpha_scissor = true
    return mat

@onready var leaf_mat = build_leaf_mat()

func build_bark_mat():
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.2, 0.1, 1.0)
    mat.params_cull_mode = StandardMaterial3D.CULL_DISABLED
    mat.params_diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
    return mat

@onready var bark_mat = build_bark_mat()

            
var bark_vertices = PackedVector3Array()

var leaf_verts   = PackedVector3Array()
var leaf_uvs     = PackedVector2Array()
var leaf_normals = PackedVector3Array()

func add_children(bit : TreeBit, parent : Node3D) -> void:
    if bit.parent:
        SewTest.build(bark_vertices, bit.parent.end_ring, bit.end_ring)
        for child in bit.children:
            add_children(child, geo)
        
        if bit.size < 0.4:
            for leaf in leaves:
                if (bit.position - leaf).length() < 1.5:
                    return
            
            var size = lerp(6.0, 12.0, bit.size * 2.0)
            
            var xform : Transform3D = Transform3D.IDENTITY
            xform = xform.rotated(Vector3.UP, randf() * PI * 2.0)
            xform = xform.rotated(Vector3.RIGHT, randf() * PI * 2.0)
            xform = xform.rotated(Vector3.BACK, randf() * PI * 2.0)
            #xform = xform.translated()
            
            for i in [0, 1, 2, 2, 1, 3, 0, 2, 1, 1, 2, 3]:
                var vert = xform * (vec3_quad[i] * size / 2.0)
                leaf_verts.push_back(vert + bit.position)
                leaf_uvs.push_back(vec2_quad[i])
                
                var normal_a = (vert + bit.position).normalized()
                var normal_b = (vert + bit.position - Vector3(0, 8, 0)).normalized()
                var dist_to_dummy = (vert + bit.position - Vector3(0, 8, 0)).length()
                var rank = clamp(dist_to_dummy / 8.0, 0.0, 1.0)
                var normal = normal_b.lerp(normal_a, rank).normalized()
                #var normal = normal_a
                
                leaf_normals.push_back(normal)
            
            leaves.push_back(bit.position)
        return
    else:
        for child in bit.children:
            add_children(child, geo)
        return

var leaves = []
var geo = null
var current_seed = hash(str(Time.get_unix_time_from_system()))
func new_tree():
    if geo:
        geo.queue_free()
        remove_child(geo)
    
    bark_vertices.clear()
    leaf_verts.clear()
    leaf_uvs.clear()
    leaf_normals.clear()
    
    leaves = []
    
    current_seed = hash(str(Time.get_unix_time_from_system()))
    print("seed: ", current_seed)
    seed(current_seed)
    
    var root = TreeBit.new()
    root.add_children()
    add_children(root, self)
    
    var mesh = ArrayMesh.new()
    
    # add wood
    
    var bark_arrays = []
    bark_arrays.resize(Mesh.ARRAY_MAX)
    bark_arrays[Mesh.ARRAY_VERTEX] = bark_vertices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bark_arrays)
    var bark_surface = mesh.get_surface_count() - 1
    mesh.surface_set_material(bark_surface, bark_mat)
    
    var tool = SurfaceTool.new()
    tool.create_from(mesh, bark_surface)
    tool.generate_normals()
    mesh.clear_surfaces()
    tool.commit(mesh)
    
    # add leaves
    
    var leaf_arrays = []
    leaf_arrays.resize(Mesh.ARRAY_MAX)
    leaf_arrays[Mesh.ARRAY_VERTEX] = leaf_verts
    leaf_arrays[Mesh.ARRAY_TEX_UV] = leaf_uvs
    leaf_arrays[Mesh.ARRAY_NORMAL] = leaf_normals

    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, leaf_arrays)
    var leaf_surface = mesh.get_surface_count() - 1
    mesh.surface_set_material(leaf_surface, leaf_mat)
    
    # add to world
    
    geo = MeshInstance3D.new()
    geo.mesh = mesh
    add_child(geo)

class MultiSignal extends RefCounted:
    signal first(int)
    signal all(int)
    var count : int = 0
    var total : int = 0
    func connectify(sig : Signal, which : int):
        if count != 0:
            # refuse new connections if at least one signal has already gone off
            return
        total += 1
        
        var r = await sig
        
        count += 1
        if count == 1:
            first.emit(which)
        if count == total:
            all.emit(which)

func save_gltf():
    var dialog = FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.add_filter("*.glb", "GLTF File")
    dialog.current_file = "tree.glb"
    add_child(dialog)
    dialog.popup_centered_ratio()
    
    var multi = MultiSignal.new()
    multi.connectify(dialog.file_selected, 0)
    multi.connectify(dialog.close_requested, 1)
    multi.connectify(dialog.canceled, 2)
    var which = await multi.first
    
    dialog.queue_free()
    
    print(which)
    
    if which == 0 or which == 3:
        var fname = dialog.current_path
        print(fname)
        
        var gltf = GLTFDocument.new()
        var gltf_state = GLTFState.new()
        gltf.append_from_scene(geo, gltf_state)
        var buffer = gltf.generate_buffer(gltf_state)
        
        var f = FileAccess.open(fname, FileAccess.WRITE)
        f.store_buffer(buffer)
        f.close()
    

func _ready():
    $Button.connect("pressed", Callable(self, "new_tree"))
    $Button2.connect("pressed", Callable(self, "save_gltf"))
    new_tree()

var sensitivity = 0.22
func _input(_event):
    if _event is InputEventMouseButton:
        var event : InputEventMouseButton = _event
        if event.button_index == 4 and event.pressed:
            $Node3D/Camera3D.position.z *= 0.8
        elif event.button_index == 5 and event.pressed:
            $Node3D/Camera3D.position.z /= 0.8
        $Node3D/Camera3D.position.z = clamp($Node3D/Camera3D.position.z, 1, 64)
    
    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
            if event.shift_pressed:
                var scale = sensitivity * $Node3D/Camera3D.position.z * 0.01
                $Node3D.translate_object_local(Vector3.UP    * event.relative.y * scale)
                $Node3D.translate_object_local(Vector3.RIGHT * -event.relative.x * scale)
            else:
                $Node3D.rotation_degrees.x -= event.relative.y * sensitivity
                $Node3D.rotation_degrees.y -= event.relative.x * sensitivity
    
