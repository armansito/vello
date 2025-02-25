// Copyright 2023 The Vello authors
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! Raw scene encoding.

mod binning;
mod clip;
mod config;
mod draw;
mod encoding;
#[cfg(feature = "full")]
mod glyph;
#[cfg(feature = "full")]
mod glyph_cache;
#[cfg(feature = "full")]
mod image_cache;
mod math;
mod monoid;
mod path;
#[cfg(feature = "full")]
mod ramp_cache;
mod resolve;

pub use binning::BinHeader;
pub use clip::{Clip, ClipBbox, ClipBic, ClipElement};
pub use config::{
    BufferSize, BufferSizes, BumpAllocators, ConfigUniform, IndirectCount, RenderConfig,
    WorkgroupCounts, WorkgroupSize,
};
pub use draw::{
    DrawBbox, DrawBeginClip, DrawColor, DrawImage, DrawLinearGradient, DrawMonoid,
    DrawRadialGradient, DrawTag,
};
pub use encoding::{Encoding, StreamOffsets};
pub use math::Transform;
pub use monoid::Monoid;
pub use path::{
    Cubic, LineSoup, Path, PathBbox, PathEncoder, PathMonoid, PathSegment, PathSegmentType,
    PathTag, SegmentCount, Tile,
};
pub use resolve::{resolve_solid_paths_only, Layout};

#[cfg(feature = "full")]
pub use {
    encoding::Resources,
    glyph::{Glyph, GlyphRun},
    ramp_cache::Ramps,
    resolve::{Patch, Resolver},
};
