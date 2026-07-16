//! C FFI bindings for chunk-your-tools.
//!
//! JSON outputs are written to `char**` out parameters; free with [`cyt_free_string`].
#![allow(unsafe_op_in_unsafe_fn)]

mod catalog;
mod catalog_io;
mod error;
mod json_util;
mod memory;
mod paths;
mod policies;
mod retrieve;
mod runtime;

pub use error::{
    CYT_ERR_ALLOC, CYT_ERR_INVALID_ARG, CYT_ERR_INVALID_HANDLE, CYT_ERR_INVALID_UTF8, CYT_ERR_IO,
    CYT_ERR_JSON, CYT_ERR_NULL_PTR, CYT_ERR_PANIC, CYT_OK, cyt_clear_error, cyt_get_last_error,
};
pub use memory::{cyt_free_string, cyt_get_version};

pub use catalog::{cyt_build_catalog_index, cyt_catalog_tool_count};
pub use policies::cyt_classify_optional_chunks_batch;

pub use catalog_io::CytCatalogBuilder;
pub use retrieve::CytDecomposedCatalog;
