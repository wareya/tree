extends Spatial


class TreeBit extends Reference:
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
        var heading : Vector3 = Vector3.UP
        if parent:
            heading = (position - parent.position).normalized()
            if heading.y < 0.0 or size > 0.3:
                heading = heading.linear_interpolate(Vector3.UP, 0.2).normalized()
        
        end_ring = []
        var vert_count = int(size*8) + 1
        if vert_count < 3:
            vert_count = 3
        
        for i in range(vert_count):
            var rad = i/float(vert_count) * PI * 2.0
            #var v = Vector3(sin(rad), 0, cos(rad)) * size
            var v = Vector3(sin(rad), cos(rad), 0) * size
            var t : Transform = Transform.IDENTITY
            t = t.looking_at(heading, Vector3.UP + Vector3(0.0001, 0.00008981, -0.000014389))
            v = t.basis.xform(v)
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

func add_children(bit : TreeBit, parent : Spatial):
    #var geometry = CylinderMesh.new()
    #var mat = SpatialMaterial.new()
    #mat.albedo_color = Color.brown
    #geometry.material = mat
    #geometry.top_radius = bit.size * 0.5
    #geometry.bottom_radius = bit.size * 0.5
    #if bit.parent:
    #    geometry.bottom_radius = bit.parent.size * 0.5
    #geometry.height = bit.size
    #if bit.parent:
    #    geometry.height = (bit.position - bit.parent.position).length()
    #
    #var meshinstance = MeshInstance.new()
    #meshinstance.mesh = geometry
    #parent.add_child(meshinstance)
    #meshinstance.global_translation = bit.position
    #meshinstance.look_at(parent.global_translation + Vector3(0.0, -0.0001, 0.0), Vector3.UP + Vector3(0.00001, #-0.0001, 0.001))
    #meshinstance.rotate_object_local(Vector3.RIGHT, PI*0.5)
    #
    #if bit.parent:
    #    #meshinstance.global_translation = (bit.position - bit.parent.position).length()
    #    meshinstance.translate_object_local(Vector3(0.0, geometry.height * -0.5, 0.0))
    #else:
    #    meshinstance.translate_object_local(Vector3(0.0, geometry.height * 0.5, 0.0))
    #
    #for child in bit.children:
    #    add_children(child, meshinstance)
    
    if bit.parent:
        var geo = SewTest.build(bit.parent.end_ring, bit.end_ring)
        parent.add_child(geo)
        for child in bit.children:
            add_children(child, geo)
        
        if bit.size < 0.4:
            for leaf in leaves:
                if (bit.position - leaf).length() < 1.5:
                    return geo
            
            var size = lerp(6.0, 12.0, bit.size * 2.0)
            
            var xform : Transform = Transform.IDENTITY
            xform = xform.rotated(Vector3.UP, randf() * PI * 2.0)
            xform = xform.rotated(Vector3.RIGHT, randf() * PI * 2.0)
            xform = xform.rotated(Vector3.BACK, randf() * PI * 2.0)
            #xform = xform.translated()
            
            var verts   = PoolVector3Array()
            var uvs     = PoolVector2Array()
            var normals = PoolVector3Array()
            
            for i in [0, 1, 2, 2, 1, 3, 0, 2, 1, 1, 2, 3]:
                var vert = xform.xform(vec3_quad[i] * size / 2.0)
                verts  .push_back(vert)
                uvs    .push_back(vec2_quad[i])
                
                var normal_a = (vert + bit.position).normalized()
                var normal_b = (vert + bit.position - Vector3(0, 8, 0)).normalized()
                var dist_to_dummy = (vert + bit.position - Vector3(0, 8, 0)).length()
                var rank = clamp(dist_to_dummy / 8.0, 0.0, 1.0)
                var normal = normal_b.linear_interpolate(normal_a, rank).normalized()
                #var normal = normal_a
                
                normals.push_back(normal)
            
            var arrays = []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = verts
            arrays[Mesh.ARRAY_TEX_UV] = uvs
            arrays[Mesh.ARRAY_NORMAL] = normals

            var mesh = ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            
            var card = MeshInstance.new()
            #var mesh = QuadMesh.new()
            #mesh.size = Vector2.ONE * size
            card.mesh = mesh
            var mat = SpatialMaterial.new()
            mat.albedo_texture = preload("res://art/just leaves.png")
            
            mat.params_diffuse_mode = SpatialMaterial.DIFFUSE_LAMBERT
            mat.params_use_alpha_scissor = true
            #mat.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
            #mat.params_cull_mode = SpatialMaterial.CULL_DISABLED
            card.material_override = mat
            
            geo.add_child(card)
            card.global_translation = bit.position
            
            leaves.push_back(bit.position)
        return geo
    else:
        var start_ring = []
        var vert_count = int(bit.size*8) + 1
        for i in range(vert_count):
            var rad = i/float(vert_count) * PI * 2.0
            start_ring.push_back(Vector3(sin(rad), 0, cos(rad)) * bit.size)
        
        var geo = SewTest.build(start_ring, bit.end_ring)
        parent.add_child(geo)
        for child in bit.children:
            add_children(child, geo)
        return geo

var leaves = []
var geo = null
func new_tree():
    if geo:
        geo.queue_free()
        remove_child(geo)
    leaves = []
    
    randomize()
    #seed(27452)
    var root = TreeBit.new()
    root.add_children()
    geo = add_children(root, self)

func _ready():
    $Button.connect("pressed", self, "new_tree")
    new_tree()

var sensitivity = 0.22
func _input(_event):
    if _event is InputEventMouseButton:
        var event : InputEventMouseButton = _event
        if event.button_index == 4 and event.pressed:
            $Spatial/Camera.translation.z *= 0.8
        elif event.button_index == 5 and event.pressed:
            $Spatial/Camera.translation.z /= 0.8
        $Spatial/Camera.translation.z = clamp($Spatial/Camera.translation.z, 1, 64)
    
    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if event.button_mask & BUTTON_MASK_MIDDLE:
            if event.shift:
                var scale = sensitivity * $Spatial/Camera.translation.z * 0.01
                $Spatial.translate_object_local(Vector3.UP    * event.relative.y * scale)
                $Spatial.translate_object_local(Vector3.RIGHT * -event.relative.x * scale)
            else:
                $Spatial.rotation_degrees.x -= event.relative.y * sensitivity
                $Spatial.rotation_degrees.y -= event.relative.x * sensitivity
    
