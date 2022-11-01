// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Also licensed under MIT license, at your choice.

// Tile allocation (and zeroing of tiles)

#import config
#import bump
#import drawtag

@group(0) @binding(0)
var<storage> config: Config;

@group(0) @binding(1)
var<storage> scene: array<u32>;

@group(0) @binding(2)
var<storage> draw_bboxes: array<vec4<f32>>;

@group(0) @binding(3)
var<storage, read_write> bump: BumpAllocators;

// TODO: put this in the right place, dedup
struct Path {
    // bounding box in pixels
    bbox: vec4<u32>,
    // offset (in u32's) to tile rectangle
    tiles: u32,
}

struct Tile {
    backdrop: i32,
    segments: u32,
}

@group(0) @binding(4)
var<storage, read_write> paths: array<Path>;

@group(0) @binding(5)
var<storage, read_write> tiles: array<Tile>;

let WG_SIZE = 256u;

var<workgroup> sh_tile_count: array<u32, WG_SIZE>;
var<workgroup> sh_tile_offset: u32;

@compute @workgroup_size(256)
fn main(
    @builtin(global_invocation_id) global_id: vec3<u32>,
    @builtin(local_invocation_id) local_id: vec3<u32>,
) {
    // scale factors useful for converting coordinates to tiles
    // TODO: make into constants
    let SX = 1.0 / f32(TILE_WIDTH);
    let SY = 1.0 / f32(TILE_HEIGHT);

    let drawobj_ix = global_id.x;
    var drawtag = DRAWTAG_NOP;
    if drawobj_ix < config.n_drawobj {
        drawtag = scene[config.drawtag_base + drawobj_ix];
    }
    var x0 = 0;
    var y0 = 0;
    var x1 = 0;
    var y1 = 0;
    if drawtag != DRAWTAG_NOP && drawtag != DRAWTAG_END_CLIP {
        let bbox = draw_bboxes[drawobj_ix];
        x0 = i32(floor(bbox.x * SX));
        y0 = i32(floor(bbox.y * SY));
        x1 = i32(ceil(bbox.z * SX));
        y1 = i32(ceil(bbox.w * SY));
    }
    let ux0 = u32(clamp(x0, 0, i32(config.width_in_tiles)));
    let uy0 = u32(clamp(y0, 0, i32(config.height_in_tiles)));
    let ux1 = u32(clamp(x1, 0, i32(config.width_in_tiles)));
    let uy1 = u32(clamp(y1, 0, i32(config.height_in_tiles)));
    let tile_count = (ux1 - ux0) * (uy1 - uy0);
    var total_tile_count = tile_count;
    sh_tile_count[local_id.x] = tile_count;
    for (var i = 0u; i < firstTrailingBit(WG_SIZE); i += 1u) {
        workgroupBarrier();
        if local_id.x < (1u << i) {
            total_tile_count += sh_tile_count[local_id.x - (1u << i)];
        }
        workgroupBarrier();
        sh_tile_count[local_id.x] = total_tile_count;
    }
    if local_id.x == WG_SIZE - 1u {
        sh_tile_offset = atomicAdd(&bump.tile, total_tile_count);
    }
    workgroupBarrier();
    let tile_offset = sh_tile_offset;
    if drawobj_ix < config.n_drawobj {
        let tile_subix = select(0u, sh_tile_count[local_id.x - 1u], local_id.x > 0u);
        let bbox = vec4<u32>(ux0, uy0, ux1, uy1);
        let path = Path(bbox, tile_offset + tile_subix);
    }

    // zero allocated memory
    // Note: if the number of draw objects is small, utilization will be poor.
    // There are two things that can be done to improve that. One would be a
    // separate (indirect) dispatch. Another would be to have each workgroup
    // process fewer draw objects than the number of threads in the wg.
    let total_count = sh_tile_count[WG_SIZE - 1u];
    for (var i = local_id.x; i < total_count; i += WG_SIZE) {
        // Note: could format output buffer as u32 for even better load
        // balancing, as does piet-gpu.
        tiles[tile_offset + i] = Tile(0, 0u);
    }
}