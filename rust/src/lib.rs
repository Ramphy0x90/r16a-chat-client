// matrix-sdk's deeply nested futures overflow the default limit when spawned.
#![recursion_limit = "256"]

pub mod frb_generated;
pub mod api;
