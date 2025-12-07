13
154618822660
3905399558095922 1764614866020845400
{
  "name": "Tree_Small",
  "local_enabled": true,
  "local_position": {
    "X": 5.9749445915222168,
    "Y": -7.7772555351257324
  },
  "local_rotation": 0,
  "local_scale": {
    "X": 0.6999999880790710,
    "Y": 0.6999999880790710
  },
  "previous_sibling": "3190820729980027:1764299197265305200",
  "next_sibling": "3905363373868922:1764614856498783900",
  "linked_prefab": "Tree_Small.prefab"
},
{
  "cid": 1,
  "aoid": "3905399558614774:1764614866020981200",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_small.png"
  }
},
{
  "cid": 2,
  "aoid": "3905399558713498:1764614866021007000",
  "component_type": "Internal_Component",
  "internal_component_type": "Circle_Collider",
  "data": {
    "make_navmesh_loop": true,
    "flip_navmesh_loop": true,
    "size": 0.5199998021125793
  }
},
{
  "cid": 3,
  "aoid": "3905399558801430:1764614866021030200",
  "component_type": "Internal_Component",
  "internal_component_type": "Tree",
  "data": {
    "sprite": "3905399558614774:1764614866020981200",
    "chopped_sprite": "3905399558957154:1764614866021071100"
  }
},
{
  "cid": 4,
  "aoid": "3905399558878950:1764614866021050600",
  "component_type": "Internal_Component",
  "internal_component_type": "Clickable",
  "data": {
    "required_range": 1.5000000000000000
  }
},
{
  "cid": 5,
  "aoid": "3905399558957154:1764614866021071100",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_small_chopped.png"
  }
}
