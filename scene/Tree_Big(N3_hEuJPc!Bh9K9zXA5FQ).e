13
103079215113
3905363375592412 1764614856499237200
{
  "name": "Tree_Big",
  "local_enabled": true,
  "local_position": {
    "X": -6.8082213401794434,
    "Y": -3.7817158699035645
  },
  "local_rotation": 0,
  "local_scale": {
    "X": 0.3499999940395355,
    "Y": 0.3499999940395355
  },
  "previous_sibling": "3905363373868922:1764614856498783900",
  "next_sibling": "3048657229514663:1764261786225742100",
  "parent": "1056443631040892:1763450818243280900",
  "linked_prefab": "Tree_Big.prefab"
},
{
  "cid": 1,
  "aoid": "3905363376057152:1764614856499359200",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_medium.png"
  }
},
{
  "cid": 2,
  "aoid": "3905363376135052:1764614856499379700",
  "component_type": "Internal_Component",
  "internal_component_type": "Circle_Collider",
  "data": {
    "make_navmesh_loop": true,
    "flip_navmesh_loop": true,
    "size": 0.8999996781349182
  }
},
{
  "cid": 3,
  "aoid": "3905363376221274:1764614856499402400",
  "component_type": "Internal_Component",
  "internal_component_type": "Tree",
  "data": {
    "sprite": "3905363376057152:1764614856499359200",
    "chopped_sprite": "3905363376370576:1764614856499441700"
  }
},
{
  "cid": 4,
  "aoid": "3905363376297198:1764614856499422400",
  "component_type": "Internal_Component",
  "internal_component_type": "Clickable",
  "data": {
    "required_range": 1.5000000000000000
  }
},
{
  "cid": 5,
  "aoid": "3905363376370576:1764614856499441700",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_medium_chopped.png"
  }
}
