embedded_components {
  id: "body_l"
  type: "sprite"
  data: "default_animation: \"player_1\"\n"
  "material: \"/materials/sprite_world.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/main/sprites.atlas\"\n"
  "}\n"
  position {
    x: -16.0
    y: 0.0
    z: 0.0
  }
  rotation {
    x: 0.0
    y: 0.0
    z: 0.0
    w: 1.0
  }
}
embedded_components {
  id: "body_r"
  type: "sprite"
  data: "default_animation: \"player_1_flipped\"\n"
  "material: \"/materials/sprite_world.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/main/sprites.atlas\"\n"
  "}\n"
  position {
    x: 16.0
    y: 0.0
    z: 0.0
  }
  rotation {
    x: 0.0
    y: 0.0
    z: 0.0
    w: 1.0
  }
}
