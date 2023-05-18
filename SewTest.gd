extends Node3D
class_name SewTest

static func build(vertices : PackedVector3Array, verts_bottom, verts_top):
    var closest_top = 0
    var closest_dist = (verts_bottom[0] - verts_top[0]).length()
    for i in range(1, verts_top.size()):
        var dist = (verts_bottom[0] - verts_top[i]).length()
        if dist < closest_dist:
            closest_dist = dist
            closest_top = i
    
    var looped_bottom = false
    var looped_top = false
    
    var back_bottom = 0
    var back_top = closest_top
    var i = 0
    while !looped_top or !looped_bottom:
        i += 1
        var vert_top    = verts_top   [back_top]
        var vert_bottom = verts_bottom[back_bottom]
        
        var front_top    = (back_top    + 1) % verts_top   .size()
        var front_bottom = (back_bottom + 1) % verts_bottom.size()
        
        var top_heuristic    = (verts_top   [front_top]    - vert_bottom).length()
        var bottom_heuristic = (verts_bottom[front_bottom] - vert_top)   .length()
        
        if (top_heuristic < bottom_heuristic and !looped_top) or looped_bottom:
            vertices.push_back(vert_bottom)
            vertices.push_back(vert_top)
            vertices.push_back(verts_top[front_top])
            back_top = front_top
            
            if front_top == closest_top:
                looped_top = true
        
        else:
            vertices.push_back(vert_top)
            vertices.push_back(verts_bottom[front_bottom])
            vertices.push_back(vert_bottom)
            back_bottom = front_bottom
            
            if front_bottom == 0:
                looped_bottom = true
    

func _ready():
    var verts_bottom = []
    var verts_top = []
    
    for i in range(8):
        var rad = i/8.0 * PI * 2.0
        verts_bottom.push_back(Vector3(sin(rad), 0, cos(rad)))
    
    for i in range(6):
        var rad = i/8.0 * PI * 2.0
        verts_top.push_back(Vector3(sin(rad), 1, cos(rad)))
    
    #add_child(build(verts_bottom, verts_top))

var sensitivity = 0.22
func _input(_event):
    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
            $Node3D.rotation_degrees.x -= event.relative.y * sensitivity
            $Node3D.rotation_degrees.y -= event.relative.x * sensitivity
