13
94489280522
3905363373868922 1764614856498783900
{
  "name": "Tree_Big",
  "local_enabled": true,
  "local_position": {
    "X": -6.6885981559753418,
    "Y": -1.1400396823883057
  },
  "local_rotation": 0,
  "local_scale": {
    "X": 0.3499999940395355,
    "Y": 0.3499999940395355
  },
  "previous_sibling": "3905399558095922:1764614866020845400",
  "next_sibling": "3905363375592412:1764614856499237200",
  "parent": "1056443631040892:1763450818243280900",
  "linked_prefab": "Tree_Big.prefab"
},
{
  "cid": 1,
  "aoid": "3905363374433716:1764614856498932000",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_medium.png"
  }
},
{
  "cid": 2,
  "aoid": "3905363374540458:1764614856498960100",
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
  "aoid": "3905363374635952:1764614856498985200",
  "component_type": "Internal_Component",
  "internal_component_type": "Tree",
  "data": {
    "sprite": "3905363374433716:1764614856498932000",
    "chopped_sprite": "3905363374791676:1764614856499026200"
  }
},
{
  "cid": 4,
  "aoid": "3905363374713814:1764614856499005700",
  "component_type": "Internal_Component",
  "internal_component_type": "Clickable",
  "data": {
    "required_range": 1.5000000000000000
  }
},
{
  "cid": 5,
  "aoid": "3905363374791676:1764614856499026200",
  "component_type": "Internal_Component",
  "internal_component_type": "Sprite_Renderer",
  "data": {
    "texture": "World1/park_tree_medium_chopped.png"
  }
}
