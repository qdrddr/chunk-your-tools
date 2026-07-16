//! C FFI bindings for chunk-your-tools.
//!
//! JSON outputs are written to `char**` out parameters; free with [`chunk_your_tools_free_string`].
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
    CHUNK_YOUR_TOOLS_ERR_ALLOC, CHUNK_YOUR_TOOLS_ERR_INVALID_ARG,
    CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE, CHUNK_YOUR_TOOLS_ERR_INVALID_UTF8,
    CHUNK_YOUR_TOOLS_ERR_IO, CHUNK_YOUR_TOOLS_ERR_JSON, CHUNK_YOUR_TOOLS_ERR_NULL_PTR,
    CHUNK_YOUR_TOOLS_ERR_PANIC, CHUNK_YOUR_TOOLS_OK, chunk_your_tools_clear_error,
    chunk_your_tools_get_last_error,
};
pub use memory::{chunk_your_tools_free_string, chunk_your_tools_get_version};

pub use catalog::{chunk_your_tools_build_catalog_index, chunk_your_tools_catalog_tool_count};
pub use policies::chunk_your_tools_classify_optional_chunks_batch;

pub use catalog_io::ChunkYourToolsCatalogBuilder;
pub use retrieve::ChunkYourToolsDecomposedCatalog;
